# -*- ruby -*-

source "http://rubygems.org"

gemspec path: ".."
gem "rails", "~> 3.2.13"
gem "rake", "~> 11.3"
gem "minitest", "~> 4.7.5"
gem 'test-unit', '~> 3.0'

gem "database_cleaner", github: "tommeier/database_cleaner", branch: "fix-superclass-1-1-1"

gem "coveralls", "~> 0.7.0", require: false
