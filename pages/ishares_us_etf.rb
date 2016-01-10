require "site_prism"

module IShares
    module US
    end
end

class IShares::US::ETF < SitePrism::Page

    HOLDINGS_DOWNLOAD_FILE_GLOB = "#{ticker_code}_holdings.csv"

    set_url "/us/products/etf-product-list#!type=ishares&tab=overview&view=list"

    element :ticker_code_text, ".identifier", visible: true, wait: 15
    element :holdings_download_link, "a", text: "Detailed Holdings and Analytics", visible: true

    def ticker_code
        ticker_code_text.text
    end

    def has_distributions?
        Broker.fund_has_distributions? ticker_code.text
    end

    def has_holdings?
        Broker.fund_has_holdings? ticker_code.text
    end

    def hide_obscuring_elements
        Capybara.current_session.execute_script(%q(
            $("body").append("<style type='text/css'>.sticky-wrapper, .sticky-footer { position: static !important }</style>")
        ))
    end

    def wait_for_holdings_download(ticker_code)
        downloaded_file_path = nil

        # Clicking the link doesn't always launch a download, so attempt this multiple times.
        (1..10).each do |loop_count|
            holdings_download_link.click

            downloaded_file_path = wait_for_download(HOLDINGS_DOWNLOAD_FILE_GLOB)

            break if downloaded_file_path
        end

        raise "Could not download #{ticker_code} holdings." if !downloaded_file_path

        downloaded_file_path
    end

    def fetch_etf_info(expected_ticker_code, fund_html_file, fund_holdings_file)
        raise "Ticker codes do not match #{expected_ticker_code} != #{ticker_code}" if expected_ticker_code != ticker_code

        hide_obscuring_elements

        if has_holdings?
            downloaded_holdings_csv = wait_for_holdings_download(ticker_code)
            FileUtils.move downloaded_holdings_csv, fund_holdings_file
        end

        if has_distributions?
            click_link "Distributions"
            tabs_distributions = find("#tabsDistributions", visible: true)

            within(tabs_distributions) do
                find("a", text: "Table", visible: true)
                click_link "Table"
                sleep 1
                show_all_links = all(".show-all a")
                if show_all_links.length > 0
                    show_all_links[0].click
                end

                find("#distroTable tbody tr", match: :first, wait: 15) # Wait for rows to load.
            end
        end

        File.write(fund_html_file, find("body")[:innerHTML])
    end
end
