# frozen_string_literal: true
require_dependency 'content_security_policy/builder'
require_dependency 'content_security_policy/extension'

class ContentSecurityPolicy
  class << self
    def policy
      new.build
    end

    def base_url
      @base_url || Discourse.base_url
    end
    attr_writer :base_url
  end

  def build
    builder = Builder.new

    Extension.theme_extensions.each { |extension| builder << extension }
    Extension.plugin_extensions.each { |extension| builder << extension }
    builder << Extension.site_setting_extension

    builder.build
  end
end

CSP = ContentSecurityPolicy
