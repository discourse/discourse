# frozen_string_literal: true

require "openssl"
require "open-uri"
require "multi_json"
require "nokogiri"
require "mustache"
require "ostruct"
require "cgi"
require "net/http"
require "digest"
require "sanitize"
require_relative "onebox/sanitize_config"

module Onebox
  DEFAULTS = {
    connect_timeout: 5,
    timeout: 10,
    max_download_kb: 2048, # 2MB
    load_paths: [File.join(Rails.root, "lib/onebox/templates")],
    allowed_ports: [80, 443],
    allowed_schemes: %w[http https],
    sanitize_config: SanitizeConfig::ONEBOX,
    redirect_limit: 5,
  }.freeze

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

require_relative "onebox/preview"
require_relative "onebox/status_check"
require_relative "onebox/matcher"
require_relative "onebox/engine"
require_relative "onebox/layout"
require_relative "onebox/view"
