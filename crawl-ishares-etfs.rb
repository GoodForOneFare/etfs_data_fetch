# Note: for consistent results, stub out slow-loading external servers in hosts:
# ```
# 127.0.0.1 mookie1.com
# 127.0.0.1 tags.tiqcdn.com
# 127.0.0.1 metrics.blackrock.com
# 127.0.0.1 universal.iperceptions.com
# ```
# Without adding the above, tests are prone to failing with obscure network timeouts.

require 'capybara'
require 'capybara/dsl'
require 'capybara/selenium/driver'
require 'fileutils'
require_relative 'globals'

include Capybara::DSL

Capybara.register_driver :selenium do |app|
  Capybara::Selenium::Driver.new(app, :browser => :chrome)
end

Capybara.default_driver = :selenium
Capybara.app_host = "http://www.blackrock.com"
Capybara.default_max_wait_time = 3

visit('/ca/individual/en/products/product-list#categoryId=1&lvl2=overview')
find('a.investor-type-0', visible: true).click
find('.enter-site a.button').click

find('.colFundName a', match: :first, wait: 20) # Wait for links to load.

links = all('.colFundName a')
hrefs = links.map do |link| link[:href] end

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

# .c -doesn't match holdings name
# svr a
# xmh a
# xmc a

def has_distributions?(ticker_code)
	!%w(CGL CGL.C SVR SVR.C).include?(ticker_code)
end

def crawl_fund(href, data_dir)
	visit href
	sleep 3

	ticker_code = find('.identifier').text()

	Capybara.current_session.execute_script(%q(
		$('body').append("<style type='text/css'>.sticky-wrapper { position: static !important }</style>")
	))

	downloaded_holdings_csv = wait_for_ishares_ca_holdings_download(ticker_code)

	if has_distributions?(ticker_code)
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

	File.write("#{data_dir}/#{ticker_code}.html", find('body')[:innerHTML])
	sleep 2
	FileUtils.move downloaded_holdings_csv, data_dir
end

dir = data_dir "ishares", "ca", DateTime.now
FileUtils.mkpath dir
puts "Saving data to #{dir}."

hrefs.each do |href|
	begin
		puts "Crawling #{href}"
		crawl_fund(href, dir)
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