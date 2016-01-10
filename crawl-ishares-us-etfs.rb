require 'fileutils'
require_relative 'globals'
require_relative 'capybara_setup'
require_relative 'broker'

begin
	Capybara.app_host = "https://www.ishares.com"
	visit("/us/products/etf-product-list#!type=ishares&tab=overview&view=list")

	find('a', text: "Find an ETF").hover
	find(".showAllLinks", visible: true).click
	find('.colLocalExchangeTicker a', match: :first)
	links = all('.colLocalExchangeTicker a')
	fund_links = links.map do |link|
		FundLink.new(link.text, link[:href])
	end

rescue Exception => e
	puts "Could not retrieve list of funds."
	puts e.message
	puts e.backtrace

	require 'pry'
	binding.pry
end

def wait_for_holdings_download(ticker_code)
	holdings_path = "#{$downloads_dir}/#{ticker_code}_holdings.csv"
	File.delete(holdings_path) if File.exist?(holdings_path)

	# Clicking the link doesn't always launch a download, so attempt this multiple times.
	(1..10).each do |loop_count|
		p "Loop #{loop_count}"
		click_link "Detailed Holdings and Analytics"

		# Wait for the file to appear.
		(1..10).each do |check_count|
			p "\tCheck #{check_count}"
			sleep(0.5)
			break if File.exist?(holdings_path)
		end

		break if File.exist?(holdings_path)
	end

	raise "Could not download #{ticker_code} holdings." if !File.exist?(holdings_path)

	holdings_path
end

def crawl_etf(expected_ticker_code, href, fund_html_file, fund_holdings_file)

	visit href

	ticker_code = find('.identifier').text()
	raise "Ticker codes do not match #{expected_ticker_code} != #{ticker_code}" if expected_ticker_code != ticker_code
	has_distributions = Broker.fund_has_distributions?(ticker_code)
	has_holdings = Broker.fund_has_holdings?(ticker_code)

	Capybara.current_session.execute_script(%q(
		$('body').append("<style type='text/css'>.sticky-wrapper, .sticky-footer { position: static !important }</style>")
	))

	if has_holdings
		downloaded_holdings_csv = wait_for_holdings_download(ticker_code)
		FileUtils.move downloaded_holdings_csv, fund_holdings_file
	end

	if has_distributions
		click_link "Distributions"
		tabs_distributions = find("#tabsDistributions", visible: true)

		within(tabs_distributions) do

			find("a", text: "Table", visible: true)
			click_link "Table"
			sleep 1
			show_all_links = all('.show-all a')
			if show_all_links.length > 0
				show_all_links[0].click
			end

			find("#distroTable tbody tr", match: :first, wait: 15) # Wait for rows to load.
		end
	end

	File.write(fund_html_file, find('body')[:innerHTML])
end

date = DateTime.now

broker = Broker.new("ishares", "us")
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