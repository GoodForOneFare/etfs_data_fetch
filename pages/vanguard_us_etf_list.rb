require "site_prism"

module Vanguard
    module US
    end
end

class Vanguard::US::ETFList < SitePrism::Page
    set_url "/VGApp/iip/site/advisor/investments/aggregateviews?productType=product_etf#vt=performanceQuarterNav&pt=product_etf&ac=assetClass_all&ssc=false&sbm=false&acv=true&merge=functionarray2mergeStrtoAddstartIndvararraynewarraytoreturnskipfalseuseforaddingnewrowind20indexforarray2emptyNotSkiptruethisforEachfunctionitemindexifemptyNotSkipitemskipskipifskiparrayindexitemmergeStrarray2ind2ind2elsearrayindexitemiftoAddindexstartIndskipskipreturnarray&balancedSubAssetClassCategorySelectedCat=none&moneyMktSubAssetClassCategorySelectedCat=none&usBondSubAssetClassCategorySelectedCat=none&usStockSubAssetClassCategorySelectedCat=none&benchmarkMgmtCategorySelectedCat=none&assetClassCategorySelectedCat=assetClass_all&productCategorySelectedCat=product_etf"

    FUND_LINK_SELECTOR = "[rowposition=fundName] a"

    element  :first_etf_link, FUND_LINK_SELECTOR, match: :first, wait: 10
    elements :all_etf_links,  FUND_LINK_SELECTOR
    elements :all_ticker_codes, "[rowposition=symbolCol]"

    def get_fund_links
        wait_until_first_etf_link_visible 10

        links = all_etf_links
        ticker_codes = all_ticker_codes

        raise "Links and ticker code queries returned different lengths: links=#{links.length}, codes=#{ticker_codes.length}" if links.length != ticker_codes.length

        links.each_with_index.map do |link, index|
            ticker_code = ticker_codes[index].text


            path, etf_id = link[:onclick].match(/jsGoToFundDetails\('(.+?)','(\d+)/)[1..2]

            FundLink.new(ticker_code, "#{path}?fundId=#{etf_id}")
        end
    end
end
