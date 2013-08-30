require "open-uri"
require "multi_json"
require "nokogiri"
require "mustache"
require "opengraph_parser"
require "verbal_expressions"
require "ostruct"
require "moneta"

require_relative "onebox/version"
require_relative "onebox/preview"
require_relative "onebox/matcher"
require_relative "onebox/engine"

module Onebox
  DEFAULTS = {
    cache: Moneta.new(:Memory, expires: true, serializer: :json)
  }

  @@defaults = DEFAULTS

  def self.preview(url, options = @@defaults)
    Preview.new(url, options)
  end

  def self.defaults=(options)
    @@defaults = DEFAULTS.merge(options)
  end
end
