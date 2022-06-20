# frozen_string_literal: true

module QunitHelper
  def support_bundles
    [
      preload_script("discourse/tests/test-support-rails"),
      preload_script("discourse/tests/test-helpers-rails")
    ].join("\n").html_safe
  end

  def boot_bundles
    [
      preload_script("scripts/discourse-test-listen-boot"),
      preload_script("scripts/discourse-boot"),
    ].join("\n").html_safe
  end

  def theme_tests
    theme = Theme.find_by(id: request.env[:resolved_theme_id])
    return "" if theme.blank?

    _, digest = theme.baked_js_tests_with_digest
    src = "#{GlobalSetting.cdn_url}" \
      "#{Discourse.base_path}" \
      "/theme-javascripts/tests/#{theme.id}-#{digest}.js" \
      "?__ws=#{Discourse.current_hostname}"
    "<script src='#{src}'></script>".html_safe
  end
end
