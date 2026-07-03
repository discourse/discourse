# frozen_string_literal: true
require "content_security_policy/builder"
require "content_security_policy/extension"

class ContentSecurityPolicy
  class << self
    def policy(theme_id = nil, base_url: Discourse.base_url, path_info: "/", report_only: false)
      new.build(theme_id, base_url: base_url, path_info: path_info, report_only: report_only)
    end

    def nonce_placeholder(response_headers)
      response_headers[
        ::Middleware::CspScriptNonceInjector::PLACEHOLDER_HEADER
      ] ||= "[[csp_nonce_placeholder_#{SecureRandom.hex}]]"
    end
  end

  def build(theme_id, base_url:, path_info: "/", report_only: false)
    builder = Builder.new(base_url: base_url, report_only: report_only)

    Extension.theme_extensions(theme_id).each { |extension| builder << extension }
    Extension.plugin_extensions.each { |extension| builder << extension }
    builder << Extension.site_setting_extension

    builder.build
  end
end

CSP = ContentSecurityPolicy
