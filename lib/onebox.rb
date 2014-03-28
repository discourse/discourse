require "open-uri"
require "multi_json"
require "nokogiri"
require "mustache"
require "hexpress"
require "hexpress/web"
require "ostruct"
require "moneta"
require "cgi"
require "net/http"
require "digest"

module Onebox
  DEFAULTS = {
    cache: Moneta.new(:Memory, expires: true, serializer: :json),
    connect_timeout: 5,
    timeout: 10,
    load_paths: [File.join(Gem::Specification.find_by_name("onebox").gem_dir, "templates")]
  }

  @@options = DEFAULTS

  def self.preview(url, options = Onebox.options)
    Preview.new(url, options)
  end

  def self.options
    OpenStruct.new(@@options)
  end

  def self.has_matcher?(url)
    result = Matcher.new(url).oneboxed
    !!result
  end

  def self.options=(options)
    @@options = DEFAULTS.merge(options)
  end
end

require_relative "onebox/version"
require_relative "onebox/preview"
require_relative "onebox/matcher"
require_relative "onebox/engine"
require_relative "onebox/layout"
require_relative "onebox/view"
