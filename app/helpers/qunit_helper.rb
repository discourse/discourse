# frozen_string_literal: true

module QunitHelper

  def vendor_theme_tests
    if EmberCli.enabled?
      preload_script("vendor")
    else
      preload_script("vendor-theme-tests")
    end
  end

  def support_bundles
    result = [
      preload_script("discourse/tests/test-support-rails"),
      preload_script("discourse/tests/test-helpers-rails")
    ].join("\n").html_safe
  end

  def boot_bundles
    result = []
    if EmberCli.enabled?
      result << preload_script("scripts/discourse-test-listen-boot")
      result << preload_script("scripts/discourse-boot")
    else
      result << preload_script("discourse/tests/test_starter")
    end
    result.join("\n").html_safe
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
