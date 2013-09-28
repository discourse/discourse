require "open-uri"
require "multi_json"
require "nokogiri"
require "mustache"
require "opengraph_parser"
require "hexpress"
require "hexpress/web"
require "ostruct"
require "moneta"

require_relative "onebox/version"
require_relative "onebox/preview"
require_relative "onebox/matcher"
require_relative "onebox/engine"
require_relative "onebox/view"

module Onebox
  DEFAULTS = {
    cache: Moneta.new(:Memory, expires: true, serializer: :json),
    timeout: 10
  }

  @@defaults = DEFAULTS

  def self.preview(url, options = Onebox.defaults)
    Preview.new(url, options)
  end

  def self.defaults
    OpenStruct.new(@@defaults)
  end

  def self.defaults=(options)
    @@defaults = DEFAULTS.merge(options)
  end
end
