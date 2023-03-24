# frozen_string_literal: true

class MarkdownLinkifyTldsValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(value)
    !value.include?("*")
  end

  def error_message
    I18n.t("site_settings.errors.markdown_linkify_tlds")
  end
end
