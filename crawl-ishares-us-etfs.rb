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

# Configure Firefox/Capybara for grabbing
Capybara.register_driver :selenium do |app|
  Capybara::Selenium::Driver.new(app, :browser => :chrome) #, :profile =>
    #Selenium::WebDriver::Firefox::Profile.new.tap { |pr|  pr["focusmanager.testmode"] = true }
  #)
end

Capybara.default_driver = :selenium
Capybara.app_host = "https://www.ishares.com"
Capybara.default_max_wait_time = 3

visit('/us/products/product-list#categoryId=0&lvl2=overview')

find('.colLocalExchangeTicker a', match: :first)
links = all('.colLocalExchangeTicker a')
hrefs = links.map do |link| link[:href] end

def wait_for_holdings_download(fund_name)
	# TODO: get user downloads dir.
	holdings_path = "#{$downloads_dir}/#{fund_name}_holdings.csv"
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

	raise "Could not download #{fund_name} holdings." if !File.exist?(holdings_path)

	holdings_path
end

def crawl_fund(href, data_dir)

	visit href
#	sleep 3

	fund_name = find('.identifier').text()

	Capybara.current_session.execute_script(%q(
		$('body').append("<style type='text/css'>.sticky-wrapper, .sticky-footer { position: static !important }</style>")
	))

	has_distributions = !["CMDT", "CSG", "IAU", "SLV"].include?(fund_name)
	has_holdings = !["IAU", "SLV"].include?(fund_name)

	if has_holdings
		downloaded_holdings_csv = wait_for_holdings_download(fund_name)
		FileUtils.move downloaded_holdings_csv, data_dir
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

	File.write("#{data_dir}/#{fund_name}.html", find('body')[:innerHTML])
end

dir = data_dir "ishares", "us", DateTime.now
FileUtils.mkpath dir
puts "Saving data to #{dir}."

hrefs.each do |href|
	begin
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