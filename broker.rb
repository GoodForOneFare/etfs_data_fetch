FundFile = Struct.new(:html, :holdings_csv)

class Broker
    def initialize(name, country)
        @name = name
        @country = country
    end

    def create_data_dir(datetime)
        dir = data_dir(datetime)
        FileUtils.mkpath(dir)[0]
    end

    def data_dir(datetime)
        months = ["-", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

        day = datetime.mday
        month = months[datetime.month]
        year = datetime.year

        File.join($data_root_dir, "#{@name}/#{@country}/#{day}-#{month}-#{year}")
    end

    def self.fund_has_distributions?(ticker_code)
        # Commodities don't provide distributions.
        ![
            "CGL",   # Gold.
            "CGL.C",
            "CMDT",  # Misc. commodities.
            "CSG",
            "IAU",   # Gold.
            "SLV",   # Silver.
            "SVR",
            "SVR.C"
        ].include?(ticker_code)
    end

    def self.fund_has_holdings?(ticker_code)
        ![
            "IAU", # All gold.
            "SLV", # All silver.
            "VI",  # New fund; holdings will be available soon.
            "VIU"  # New fund; holdings will be available soon.
        ].include?(ticker_code)
    end

    def fund_files(datetime, ticker_code)
        base_dir = data_dir(datetime)

        FundFile.new(
            File.join(base_dir, "#{ticker_code}.html"),
            File.join(base_dir, "#{ticker_code}.csv")
        )
    end

    def downloaded?(datetime, ticker_code)
        files = fund_files(datetime, ticker_code)
        no_holdings_required = !Broker.fund_has_holdings?(ticker_code)

        File.exists?(files.html) && (no_holdings_required || File.exists?(files.holdings_csv))
    end
end