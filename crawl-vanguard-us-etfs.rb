require 'fileutils'
require_relative 'globals'
require_relative 'capybara_setup'
require_relative 'broker'
require_relative 'pages/vanguard_us_etf_list'

begin
    Capybara.app_host = "https://advisors.vanguard.com"

    etfs_page = Vanguard::US::ETFList.new
    etfs_page.load
    fund_links = etfs_page.get_fund_links

rescue Exception => e
    puts "Could not retrieve list of funds."
    puts e.message
    puts e.backtrace

    require 'pry'
    binding.pry
end

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