require 'capybara'
require 'capybara/dsl'
require 'capybara/selenium/driver'

# This gives a warning about global scope, but that's okay in this small project.
include Capybara::DSL

# Use Chrome, because it provides easy access to downloaded files.
Capybara.register_driver :selenium do |app|
  Capybara::Selenium::Driver.new(app, :browser => :chrome)
end

Capybara.default_driver = :selenium
Capybara.default_max_wait_time = 3
