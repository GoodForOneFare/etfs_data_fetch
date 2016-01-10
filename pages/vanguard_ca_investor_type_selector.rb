require "site_prism"
require_relative "./vanguard_ca_etf_list"

class Vanguard::CA::InvestorTypeSelector < SitePrism::Page

    set_url "/individual/portal.htm"

    element :individual_investor_link, "h2", text: "Individual investors"

    def go_to_etf_list
        individual_investor_link.click

        etfs_page = Vanguard::CA::ETFList.new
        etfs_page.load
        etfs_page
    end
end
