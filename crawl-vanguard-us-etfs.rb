require 'capybara'
require 'capybara/dsl'
require 'capybara/selenium/driver'
require 'fileutils'
require_relative 'globals'

include Capybara::DSL


def va_us_has_separate_holdings?(ticker_code)
	["BIV", "BLV", "EDV", "VGIT", "VGLT", "VMBS"].include?(ticker_code)
end

def wait_for_vanguard_us_holdings_download(ticker_code)
	File.delete(*Dir.glob("#{$downloads_dir}/ProductDetailsHoldings_*.csv"))

	if (va_us_has_separate_holdings?(ticker_code))
		click_link "Portfolio"
		find("#composition")
	end

	begin
		click_link("Holding details")
		using_wait_time(60) do
			click_link "Export data"
		end
	rescue
		puts "#{ticker_code} holdings not found; trying individual holdings page"
		click_link "Portfolio"
		find("#composition")
		retry
	end

	csv_files = []
	# Wait for the file to appear.
	(1..50).each do |check_count|
		p "\tCheck #{check_count}"
		sleep(0.5)
		csv_files = Dir.glob("#{$downloads_dir}/ProductDetailsHoldings_*.csv")
		break if csv_files && csv_files.length == 1
	end

	raise "Could not download #{ticker_code} holdings." if !csv_files || csv_files.length != 1

	csv_files[0]
end


# Configure Firefox/Capybara for grabbing
Capybara.register_driver :selenium do |app|
  Capybara::Selenium::Driver.new(app, :browser => :chrome) #, :profile =>
    #Selenium::WebDriver::Firefox::Profile.new.tap { |pr|  pr["focusmanager.testmode"] = true }
  #)
end

Capybara.default_driver = :selenium
Capybara.app_host = "https://advisors.vanguard.com"
Capybara.default_max_wait_time = 3

visit('/VGApp/iip/site/advisor/investments/aggregateviews?productType=product_etf#vt=performanceQuarterNav&pt=product_etf&ac=assetClass_all&ssc=false&sbm=false&acv=true&merge=functionarray2mergeStrtoAddstartIndvararraynewarraytoreturnskipfalseuseforaddingnewrowind20indexforarray2emptyNotSkiptruethisforEachfunctionitemindexifemptyNotSkipitemskipskipifskiparrayindexitemmergeStrarray2ind2ind2elsearrayindexitemiftoAddindexstartIndskipskipreturnarray&balancedSubAssetClassCategorySelectedCat=none&moneyMktSubAssetClassCategorySelectedCat=none&usBondSubAssetClassCategorySelectedCat=none&usStockSubAssetClassCategorySelectedCat=none&benchmarkMgmtCategorySelectedCat=none&assetClassCategorySelectedCat=assetClass_all&productCategorySelectedCat=product_etf')

find('[rowposition=fundName] a', match: :first, wait: 10)
links = all('[rowposition=fundName] a')

hrefs = links.map do |link|
	path, etf_id = link[:onclick].match(/jsGoToFundDetails\('(.+?)','(\d+)/)[1..2]

	"#{path}?fundId=#{etf_id}"
end


def crawl_etf(href, data_dir)
	visit(href)

	page_loaded_text = "Risk and volatility details"

	# Try to ensure everything's loaded by finding an element from the tail end of the page.
	using_wait_time(60) do
		find("a", text: page_loaded_text, match: :first)
	end

	ticker_code = find("meta[name=TICKER_SYMBOL]", visible: false)[:content]
	fund_html_file = File.join(data_dir, "#{ticker_code}.html")
	fund_holdings_file = File.join(data_dir, "#{ticker_code}.csv")

	puts "Ticker #{ticker_code}"

	if (File.exists?(fund_html_file) && File.exists?(fund_holdings_file))
		puts "\tAlready downloaded."
		sleep 2 # Don't overload the servers.
		return
	end

	File.write(fund_html_file, find('body')[:innerHTML])

	wait_for_vanguard_us_holdings_download(ticker_code)

	if va_us_has_separate_holdings?(ticker_code)
		click_link "Overview"
		using_wait_time(60) do
			find("a", text: page_loaded_text, match: :first)
		end
	end

	holdings_path = Dir.glob("#{$downloads_dir}/ProductDetailsHoldings_*.csv")[0]

	FileUtils.move holdings_path, fund_holdings_file

	if va_us_has_separate_holdings?(ticker_code)
		click_link "Price & Distributions"
		using_wait_time(30) do
			find("[id='priceForm:priceDistributionsTable'] .subDataTable tbody tr", match: :first)
		end
	end

	# TODO: save distribution history
end

dir = data_dir "vanguard", "us", DateTime.now
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