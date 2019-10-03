# frozen_string_literal: true
require 'content_security_policy/builder'
require 'content_security_policy/extension'

class ContentSecurityPolicy
  class << self
    def policy(theme_ids = [])
      new.build(theme_ids)
    end

    def base_url
      @base_url || Discourse.base_url
    end
    attr_writer :base_url
  end

  def build(theme_ids)
    builder = Builder.new

    Extension.theme_extensions(theme_ids).each { |extension| builder << extension }
    Extension.plugin_extensions.each { |extension| builder << extension }
    builder << Extension.site_setting_extension

    builder.build
  end
end

CSP = ContentSecurityPolicy
