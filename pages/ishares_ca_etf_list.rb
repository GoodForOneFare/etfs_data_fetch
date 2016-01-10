require "site_prism"

module IShares
    module CA
    end
end

class IShares::CA::ETFList < SitePrism::Page
    URL = "/ca/individual/en/products/product-list#categoryId=1&lvl2=overview"

    set_url URL

    element  :first_etf_link, ".colTicker a", match: :first, wait: 20
    elements :all_etf_links,  ".colTicker a"

    def get_fund_links
        wait_until_first_etf_link_visible 10

        all_etf_links.map do |link|
            FundLink.new(link.text, link[:href])
        end
    end
end
