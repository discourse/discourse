require "open-uri"
require "multi_json"
require "nokogiri"
require "mustache"

require_relative "oneboxer/version"
require_relative "oneboxer/preview"


module Oneboxer
  def self.preview(url, args={})
  	Preview.new(url, args)
  end
end
