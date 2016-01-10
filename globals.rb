require 'fileutils'
require_relative './fund_link'

# Only tested on Chrome + OS X.
$downloads_dir = File.expand_path("~/Downloads")
$data_root_dir = File.expand_path("~/.etfs");

FileUtils.mkpath($data_root_dir) unless File.exists?($data_root_dir)