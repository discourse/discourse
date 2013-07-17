require "coveralls"
Coveralls.wear! do
  add_filter "/spec/"
end

require "rspec"
require "pry"
require "fakeweb"
require "discourse-oneboxer"
