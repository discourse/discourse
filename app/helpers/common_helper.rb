module CommonHelper
  def render_google_analytics_code
    if Rails.env == "production" &&  SiteSetting.ga_tracking_code.present?
      render partial: "common/google_analytics"
    end
  end
end
