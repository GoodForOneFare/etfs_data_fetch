require "capybara"
require "capybara/dsl"
require "capybara/selenium/driver"

# This gives a warning about global scope, but that's okay in this small project.
include Capybara::DSL

# Use Chrome, because it provides easy access to downloaded files.
Capybara.register_driver :selenium do |app|
  Capybara::Selenium::Driver.new(app, :browser => :chrome)
end

Capybara.default_driver = :selenium
Capybara.default_max_wait_time = 3

def wait_for_download(expected_file_glob)
    downloaded_file_glob = "#{$downloads_dir}/#{expected_file_glob}"

    found_files = nil

    File.delete(*Dir.glob(downloaded_file_glob))

    # Wait for the file to appear.
    (1..10).each do |check_count|
        sleep(0.5)
        found_files = Dir.glob(downloaded_file_glob)

        break if found_files && found_files.length >= 1
    end

    (found_files && found_files.length > 0 && found_files[0]) || nil
end
