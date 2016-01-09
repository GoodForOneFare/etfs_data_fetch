require 'fileutils'
require_relative 'globals'
require_relative 'capybara_setup'

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


Capybara.app_host = "https://advisors.vanguard.com"
visit('/VGApp/iip/site/advisor/investments/aggregateviews?productType=product_etf#vt=performanceQuarterNav&pt=product_etf&ac=assetClass_all&ssc=false&sbm=false&acv=true&merge=functionarray2mergeStrtoAddstartIndvararraynewarraytoreturnskipfalseuseforaddingnewrowind20indexforarray2emptyNotSkiptruethisforEachfunctionitemindexifemptyNotSkipitemskipskipifskiparrayindexitemmergeStrarray2ind2ind2elsearrayindexitemiftoAddindexstartIndskipskipreturnarray&balancedSubAssetClassCategorySelectedCat=none&moneyMktSubAssetClassCategorySelectedCat=none&usBondSubAssetClassCategorySelectedCat=none&usStockSubAssetClassCategorySelectedCat=none&benchmarkMgmtCategorySelectedCat=none&assetClassCategorySelectedCat=assetClass_all&productCategorySelectedCat=product_etf')

find('[rowposition=fundName] a', match: :first, wait: 10)
links = all('[rowposition=fundName] a')
ticker_codes = all("[rowposition=symbolCol]")
raise "Links and ticker code queries returned different lengths: links=#{links.length}, codes=#{ticker_codes.length}" if links.length != ticker_codes.length

fund_links = links.each_with_index.map do |link, index|
	ticker_code = ticker_codes[index].text

	path, etf_id = link[:onclick].match(/jsGoToFundDetails\('(.+?)','(\d+)/)[1..2]

	FundLink.new(ticker_code, "#{path}?fundId=#{etf_id}")
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
	fund_links.each do |fund|
		puts "Crawling #{fund.ticker_code}: #{fund.href}"
		crawl_etf(fund.href, dir)
	end
rescue Exception => e
	puts e.message
	puts e.backtrace

	require 'pry'
	binding.pry
end