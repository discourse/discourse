# frozen_string_literal: true

module QunitHelper
  def theme_tests
    theme = Theme.find_by(id: request.env[:resolved_theme_id])
    return "" if theme.blank?

    _, digest = theme.baked_js_tests_with_digest
    src =
      "#{GlobalSetting.cdn_url}" \
        "#{Discourse.base_path}" \
        "/theme-javascripts/tests/#{theme.id}-#{digest}.js" \
        "?__ws=#{Discourse.current_hostname}"
    "<link rel='modulepreload' href='#{src}' data-theme-id='#{theme.id}' nonce='#{ThemeField::CSP_NONCE_PLACEHOLDER}' />".html_safe
  end
end
