require 'fileutils'

# Only tested on Chrome + OS X.
$downloads_dir = File.expand_path("~/Downloads")
$data_root_dir = File.expand_path("~/.etfs");

FileUtils.mkpath($data_root_dir) unless File.exists?($data_root_dir)

def data_dir(broker_name, country, datetime)
    months = ["-", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    day = datetime.mday
    month = months[datetime.month]
    year = datetime.year

    File.join($data_root_dir, "#{broker_name}/#{country}/#{day}-#{month}-#{year}")
end
