require "open-uri"
require "multi_json"
require "nokogiri"
require "mustache"

require_relative "onebox/version"
require_relative "onebox/preview"


module Onebox
  def self.preview(url, args={})
  	Preview.new(url, args)
  end
end
