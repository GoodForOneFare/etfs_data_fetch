require 'fileutils'
require_relative 'globals'
require_relative 'capybara_setup'
require_relative 'broker'

def wait_for_vanguard_us_holdings_download(ticker_code)
    click_link "Portfolio"
    click_link("Holding details")
    find("#composition")

    using_wait_time(10) do
        click_link "Export data"
    end

    downloaded_file_path = wait_for_download("ProductDetailsHoldings_*.csv")

    raise "Could not download #{ticker_code} holdings." if !downloaded_file_path

    downloaded_file_path
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


def crawl_etf(expected_ticker_code, href, fund_html_file, fund_holdings_file)
    visit(href)

    page_loaded_text = "Risk and volatility details"

    # Try to ensure everything's loaded by finding an element from the tail end of the page.
    using_wait_time(60) do
        find("a", text: page_loaded_text, match: :first)
    end

    ticker_code = find("meta[name=TICKER_SYMBOL]", visible: false)[:content]
    raise "Ticker codes do not match #{expected_ticker_code} != #{ticker_code}" if expected_ticker_code != ticker_code

    File.write(fund_html_file, find('body')[:innerHTML])

    holdings_path = wait_for_vanguard_us_holdings_download(ticker_code)

    click_link "Overview"
    using_wait_time(20) do
        find("a", text: page_loaded_text, match: :first)
    end

    FileUtils.move holdings_path, fund_holdings_file

    click_link "Price & Distributions"
    using_wait_time(30) do
        find("[id='priceForm:priceDistributionsTable'] .subDataTable tbody tr", match: :first)
    end

    # TODO: save distribution history
end

date = DateTime.now

broker = Broker.new("vanguard", "us")
broker.create_data_dir(date)

begin
    fund_links.each do |fund|
        if broker.downloaded?(date, fund.ticker_code)
            puts "Already downloaded #{fund.ticker_code}"
            next
        end

        files = broker.fund_files(date, fund.ticker_code)

        puts "Crawling #{fund.ticker_code}: #{fund.href}"
        crawl_etf(fund.ticker_code, fund.href, files.html, files.holdings_csv)
    end
rescue Exception => e
    puts e.message
    puts e.backtrace

    require 'pry'
    binding.pry
end