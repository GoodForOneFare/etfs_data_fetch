require 'fileutils'
require_relative 'globals'
require_relative 'capybara_setup'
require_relative 'broker'

Capybara.app_host = "http://www.blackrock.com"
visit('/ca/individual/en/products/product-list#categoryId=1&lvl2=overview')
find('a.investor-type-0', visible: true).click
find('.enter-site a.button').click

find('.colFundName a', match: :first, wait: 20) # Wait for links to load.

links = all('.colTicker a')
fund_links = links.map do |link|
	FundLink.new link.text, link[:href]
end

def wait_for_ishares_ca_holdings_download(ticker_code)
	sanitized_ticker_code = ticker_code.sub(/\./, "")

	# Glob here because Chrome sometimes appends a numerical suffix (e.g., ` (1)`to the downloaded filename,
	# so there's no canonical path to expect
	csv_glob = "#{$downloads_dir}/#{sanitized_ticker_code}*_holdings*.csv"

	csv_files = nil

	# Clicking the link doesn't always launch a download, so attempt this multiple times.
	(1..10).each do |loop_count|
		File.delete(*Dir.glob(csv_glob))

		click_link "Download Holdings"

		# Wait for the file to appear.
		(1..10).each do |check_count|
			sleep(0.5)
			csv_files = Dir.glob(csv_glob)

			break if csv_files && csv_files.length >= 1
		end

		break if csv_files && csv_files.length >= 1
	end

	raise "Could not download #{ticker_code} holdings." if !csv_files || csv_files.length == 0

	csv_files[0]
end

def crawl_etf(expected_ticker_code, href, fund_html_file, fund_holdings_file)
	visit href

	ticker_code = find('.identifier').text()
	raise "Ticker codes do not match #{expected_ticker_code} != #{ticker_code}" if expected_ticker_code != ticker_code

	has_distributions = Broker.fund_has_distributions?(ticker_code)

	Capybara.current_session.execute_script(%q(
		$('body').append("<style type='text/css'>.sticky-wrapper { position: static !important }</style>")
	))

	downloaded_holdings_csv = wait_for_ishares_ca_holdings_download(ticker_code)

	if has_distributions
		click_link "Distributions"
		tabs_distributions = find("#tabsDistributions", visible: true)

		within(tabs_distributions) do

			find("a", text: "Table", visible: true, wait: 10)
			click_link "Table"
			sleep 1
			show_all_links = all('.show-all a')
			if show_all_links.length > 0
				show_all_links[0].click
			end

			find('#distroAllTable tbody tr', match: :first, wait: 20) # Wait for rows to load.
		end
	end

	File.write(fund_html_file, find('body')[:innerHTML])
	FileUtils.move downloaded_holdings_csv, fund_holdings_file
end

date = DateTime.now

broker = Broker.new("ishares", "ca")
broker.create_data_dir(date)

fund_links.each do |fund|
	begin
		if broker.downloaded?(date, fund.ticker_code)
			puts "Already downloaded #{fund.ticker_code}"
			next
		end

		files = broker.fund_files(date, fund.ticker_code)

		puts "Crawling #{fund.ticker_code}: #{fund.href}"
		crawl_etf(fund.ticker_code, fund.href, files.html, files.holdings_csv)
	rescue Net::ReadTimeout => e
		puts "Read timeout #{e}"
		puts e.backtrace
		retry
	rescue Exception => e
		if e.message.match(/Other element would receive the click:.+IPEbgCover/)
			puts "Closing survey."
			find("*[name=IPEMap] area[alt=close]").click
			retry
		end

		puts e.message
		puts e.backtrace

		require 'pry'
		binding.pry
	end
end