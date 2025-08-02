# frozen_string_literal: true
require "content_security_policy/builder"
require "content_security_policy/extension"

class ContentSecurityPolicy
  class << self
    def policy(theme_id = nil, base_url: Discourse.base_url, path_info: "/")
      new.build(theme_id, base_url: base_url, path_info: path_info)
    end

    def nonce_placeholder(response_headers)
      response_headers[
        ::Middleware::CspScriptNonceInjector::PLACEHOLDER_HEADER
      ] ||= "[[csp_nonce_placeholder_#{SecureRandom.hex}]]"
    end
  end

  def build(theme_id, base_url:, path_info: "/")
    builder = Builder.new(base_url: base_url)

    Extension.theme_extensions(theme_id).each { |extension| builder << extension }
    Extension.plugin_extensions.each { |extension| builder << extension }
    builder << Extension.site_setting_extension

    builder.build
  end
end

CSP = ContentSecurityPolicy
