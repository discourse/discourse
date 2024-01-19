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
    has_csp = SiteSetting.content_security_policy || SiteSetting.content_security_policy_report_only
    return if !has_csp
    has_gtm = SiteSetting.gtm_container_id.present?
    include_nonce = SiteSetting.content_security_policy_include_script_src_nonce
    render partial: "common/csp_nonce" if include_nonce || has_gtm
  end

  def render_google_tag_manager_body_code
    render partial: "common/google_tag_manager_body" if SiteSetting.gtm_container_id.present?
  end
end
