# frozen_string_literal: true

module CommonHelper
  def render_google_universal_analytics_code
    if Rails.env.production? && SiteSetting.ga_universal_tracking_code.present?
      render partial: "common/google_universal_analytics"
    end
  end

  def render_google_tag_manager_head_code
    render partial: "common/google_tag_manager_head" if SiteSetting.gtm_container_id.present?
  end

  def render_google_tag_manager_body_code
    render partial: "common/google_tag_manager_body" if SiteSetting.gtm_container_id.present?
  end

  def render_adobe_analytics_tags_code
    if SiteSetting.adobe_analytics_tags_url.present?
      content_tag(:script, "", src: SiteSetting.adobe_analytics_tags_url, async: true)
    end
  end
end
