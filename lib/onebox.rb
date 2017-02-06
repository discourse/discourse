require "openssl"
require "open-uri"
require "multi_json"
require "nokogiri"
require "mustache"
require "ostruct"
require "moneta"
require "cgi"
require "net/http"
require "digest"
require "fast_blank"
require "sanitize"
require_relative "onebox/sanitize_config"

module Onebox
  DEFAULTS = {
    cache: Moneta.new(:Memory, expires: true, serializer: :json),
    connect_timeout: 5,
    timeout: 10,
    max_download_kb: (10 * 1024), # 10MB
    load_paths: [File.join(Gem::Specification.find_by_name("onebox").gem_dir, "templates")],
    allowed_ports: [80, 443],
    allowed_schemes: ["http", "https"],
    sanitize_config: Sanitize::Config::ONEBOX,
  }

  @@options = DEFAULTS

  def self.preview(url, options = Onebox.options)
    Preview.new(url, options)
  end

  def self.check(url, options = Onebox.options)
    StatusCheck.new(url, options)
  end

  def self.options
    OpenStruct.new(@@options)
  end

  def self.has_matcher?(url)
    !!Matcher.new(url).oneboxed
  end

  def self.options=(options)
    @@options = DEFAULTS.merge(options)
  end
end

require_relative "onebox/version"
require_relative "onebox/preview"
require_relative "onebox/status_check"
require_relative "onebox/matcher"
require_relative "onebox/engine"
require_relative "onebox/layout"
require_relative "onebox/view"
