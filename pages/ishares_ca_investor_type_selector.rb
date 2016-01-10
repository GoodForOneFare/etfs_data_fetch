require_relative "./ishares_ca_etf_list"

class IShares::CA::InvestorTypeSelector < SitePrism::Page
    # Use the ETF list URL.  This'll trigger a redirect there once this form is complete.
    set_url IShares::CA::ETFList::URL

    element :individual_investor, "a.investor-type-0"
    element :submit_button      , ".enter-site a.button"

    def go_to_etf_list
        load
        individual_investor.click
        submit_button.click

        IShares::CA::ETFList.new
    end
end
