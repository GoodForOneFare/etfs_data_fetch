require 'fileutils'
require_relative 'globals'
require_relative 'capybara_setup'
require_relative 'broker'
require_relative 'pages/ishares_ca_investor_type_selector'
require_relative 'pages/ishares_ca_etf_list'

begin
    Capybara.app_host = "http://www.blackrock.com"

    selector_page = IShares::CA::InvestorTypeSelector.new
    selector_page.load

    etfs_page = selector_page.go_to_etf_list
    fund_links = etfs_page.get_fund_links
rescue Exception => e
    puts "Could not retrieve list of funds."
    puts e.message
    puts e.backtrace

    require 'pry'
    binding.pry
end

def wait_for_ishares_ca_holdings_download(ticker_code)
    sanitized_ticker_code = ticker_code.sub(/\./, "")

    # Glob includes `*.csv` because Chrome sometimes appends a numerical suffix (e.g., `XUU_holdings (1).csv`)
    # to the downloaded filename, so there's no canonical path to expect.
    file_glob = "#{sanitized_ticker_code}*_holdings*.csv"

    downloaded_file_path = nil

    # Clicking the link doesn't always launch a download, so attempt this multiple times.
    (1..10).each do |loop_count|
        click_link "Download Holdings"

        downloaded_file_path = wait_for_download(file_glob)

        break if downloaded_file_path
    end

    raise "Could not download #{ticker_code} holdings." if !downloaded_file_path

    downloaded_file_path
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