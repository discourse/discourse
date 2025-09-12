require 'simplecov'
SimpleCov.minimum_coverage 100
SimpleCov.coverage_dir 'reports/coverage'
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/.bundle/"
end
