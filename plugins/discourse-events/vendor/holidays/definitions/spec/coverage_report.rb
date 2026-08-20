require 'simplecov'
require 'simplecov-rcov'
SimpleCov.minimum_coverage 100
SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
SimpleCov.coverage_dir 'reports/coverage'
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/.bundle/"
end
