# -*- ruby -*-

source "http://rubygems.org"

gemspec path: ".."
gem "rails", "~> 5.0.0"

gem "database_cleaner", github: "tommeier/database_cleaner", branch: "fix-superclass-1-1-1"

gem "coveralls", "~> 0.7.0", require: false
