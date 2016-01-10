require "site_prism"

module Vanguard
    module CA
    end
end

class Vanguard::CA::ETFList < SitePrism::Page
    set_url "/individual/etfs/etfs.htm"

    # The page has two lists that are combined into one result.
    EQUITY_SELECTOR = "*[accordionname=mf-EQUITY] .c-fundName.fixed"
    BOND_SELECTOR   = "*[accordionname=mf-BOND] .c-fundName.fixed"

    EQUITIES_LINK_SELECTOR = "#{EQUITY_SELECTOR} > div > a"
    BONDS_LINK_SELECTOR    = "#{BOND_SELECTOR}   > div > a"

    # ETF codes are in the next column after the links column.
    EQUITIES_TICKER_CODE_SELECTOR = "#{EQUITY_SELECTOR} + td"
    BONDS_TICKER_CODE_SELECTOR    = "#{BOND_SELECTOR  } + td"

    LINKS_SELECTOR = "#{EQUITIES_LINK_SELECTOR}, #{BONDS_LINK_SELECTOR}"
    TICKER_CODES_SELECTOR = "#{EQUITIES_TICKER_CODE_SELECTOR}, #{BONDS_TICKER_CODE_SELECTOR}"

    element  :first_etf_link,   LINKS_SELECTOR, match: :first, wait: 30
    elements :all_etf_links,    LINKS_SELECTOR
    elements :all_ticker_codes, TICKER_CODES_SELECTOR

    def get_fund_links
        wait_until_first_etf_link_visible 10

        links = all_etf_links
        ticker_codes = all_ticker_codes

        raise "Links and ticker code queries returned different lengths: links=#{links.length}, codes=#{ticker_codes.length}" if links.length != ticker_codes.length

        fund_links = links.each_with_index.map do |link, index|
            ticker_code = ticker_codes[index].text

            FundLink.new(ticker_code, link[:href].sub(/##/, "#") )
        end
        fund_links.uniq!
        fund_links
    end
end
