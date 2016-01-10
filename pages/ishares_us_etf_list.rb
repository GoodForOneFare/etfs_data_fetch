require "site_prism"

module IShares
    module US
    end
end

class IShares::US::ETFList < SitePrism::Page

    set_url "/us/products/etf-product-list#!type=ishares&tab=overview&view=list"

    element  :find_an_etf_header, "a", text: "Find an ETF"
    element  :show_all_links,     ".showAllLinks", visible: true

    element  :first_etf_link, ".colLocalExchangeTicker a", match: :first
    elements :all_etf_links,  ".colLocalExchangeTicker a"

    def show_all_etfs
        find_an_etf_header.hover
        show_all_links.click
        wait_until_first_etf_link_visible 10
    end

    def get_fund_links
        show_all_etfs
        all_etf_links.map do |link|
            FundLink.new(link.text, link[:href])
        end
    end
end
