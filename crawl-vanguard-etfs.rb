require "fileutils"
require_relative "globals"
require_relative "capybara_setup"
require_relative "broker"
require_relative "pages/vanguard_ca_investor_type_selector"
require_relative "pages/vanguard_ca_etf_list"

begin
    Capybara.app_host = "https://www.vanguardcanada.ca"

    selector_page = Vanguard::CA::InvestorTypeSelector.new
    selector_page.load

    etfs_page = selector_page.go_to_etf_list
    fund_links = etfs_page.get_fund_links
rescue Exception => e
    puts "Could not retrieve list of funds."
    puts e.message
    puts e.backtrace

    require "pry"
    binding.pry
end

def wait_for_vanguard_ca_holdings_download(ticker_code)
    using_wait_time(60) do
        find("a", text: "Export to spreadsheet").click
    end

    downloaded_file_path = wait_for_download("*#{ticker_code}*.csv")

    raise "Could not download #{ticker_code} holdings." if !downloaded_file_path

    downloaded_file_path
end

def crawl_etf(expected_ticker_code, href, fund_html_file, fund_holdings_file)
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
    raise "Ticker codes do not match #{expected_ticker_code} != #{ticker_code}" if expected_ticker_code != ticker_code

    has_holdings = Broker.fund_has_holdings?(ticker_code)

    File.write(fund_html_file, find("body")[:innerHTML])

    find("span", text: "Portfolio data", match: :first).click

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

date = DateTime.now

broker = Broker.new("vanguard", "ca")
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

    require "pry"
    binding.pry
end