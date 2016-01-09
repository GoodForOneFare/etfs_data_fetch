require 'fileutils'
require_relative 'globals'
require_relative 'capybara_setup'

def wait_for_vanguard_ca_holdings_download(ticker_code)
	File.delete(*Dir.glob("#{$downloads_dir}/*#{ticker_code}*.csv"))

	using_wait_time(60) do
		find("a", text: "Export to spreadsheet").click
	end

	csv_files = []
	# Wait for the file to appear.
	(1..50).each do |check_count|
		sleep(0.5)
		csv_files = Dir.glob("#{$downloads_dir}/*#{ticker_code}*.csv")
		break if csv_files && csv_files.length == 1
	end

	raise "Could not download #{ticker_code} holdings." if !csv_files || csv_files.length != 1

	csv_files[0]
end

Capybara.app_host = "https://www.vanguardcanada.ca"
visit('/individual/portal.htm')

find("h2", text: "Individual investors").click
visit "https://www.vanguardcanada.ca/individual/etfs/etfs.htm"

va_ca_all_rows_selector = "*[accordionname=mf-EQUITY] .c-fundName > div > a, *[accordionname=mf-BOND] .c-fundName > div > a"
find(va_ca_all_rows_selector, match: :first, wait: 30)
links = all(va_ca_all_rows_selector)

hrefs = links.map do |link| link[:href].sub(/##/, "#") end
hrefs.uniq!

def crawl_etf(href, data_dir)
	visit(href)

	page_loaded_text = if href.include?("=BOND") then
		"Distribution by issuer (% of fund)"
	else
		"Sector weighting"
	end

	# Try to ensure everything's loaded by finding an element from the tail end of the page.
	using_wait_time(60) do
		find("th", text: page_loaded_text)
	end

	ticker_code = find("li", text: "Ticker symbol").find("span").text()
	has_holdings = !["IAU", "SLV"].include?(ticker_code)
	puts "Ticker #{ticker_code}"

	fund_html_file = File.join(data_dir, "#{ticker_code}.html")
	fund_holdings_file = File.join(data_dir, "#{ticker_code}.csv")

	if (File.exists?(fund_html_file) && (has_holdings && File.exists?(fund_holdings_file)))
		puts "\tAlready downloaded."
		sleep 2 # Don't overload the servers.
		return
	end

	File.write(fund_html_file, find('body')[:innerHTML])

	find('span', text: 'Portfolio data', match: :first).click

	if has_holdings
		find("h3", text: "Holding details")
		if (all("#noHoldingsData").length == 0)
			holdings_csv = wait_for_vanguard_ca_holdings_download(ticker_code)
			FileUtils.move holdings_csv, fund_holdings_file
		else
			puts "#{ticker_code} - no holding details found."
		end
	end

	find("a", text: "Prices & distributions").click
	click_link "View distribution history"

	# TODO: save distribution history
end

dir = data_dir "vanguard", "ca", DateTime.now
FileUtils.mkpath dir
puts "Saving data to #{dir}."

begin
	hrefs.each do |href|
		puts "Crawling #{href}"
		crawl_etf(href, dir)
	end
rescue Exception => e
	puts e.message
	puts e.backtrace

	require 'pry'
	binding.pry
end