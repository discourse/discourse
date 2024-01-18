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

  def render_csp_nonce_code
    if SiteSetting.content_security_policy || SiteSetting.content_security_policy_report_only
      render partial: "common/csp_nonce"
    end
  end

  def render_google_tag_manager_body_code
    render partial: "common/google_tag_manager_body" if SiteSetting.gtm_container_id.present?
  end
end
