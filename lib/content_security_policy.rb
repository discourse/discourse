# frozen_string_literal: true
require 'content_security_policy/builder'
require 'content_security_policy/extension'

class ContentSecurityPolicy
  class << self
    def policy(theme_ids = [], base_url: Discourse.base_url, path_info: "/")
      new.build(theme_ids, base_url: base_url, path_info: path_info)
    end
  end

  def build(theme_ids, base_url:, path_info: "/")
    builder = Builder.new(base_url: base_url)

    Extension.theme_extensions(theme_ids).each { |extension| builder << extension }
    Extension.plugin_extensions.each { |extension| builder << extension }
    builder << Extension.site_setting_extension
    builder << Extension.path_specific_extension(path_info)

    builder.build
  end
end

CSP = ContentSecurityPolicy
