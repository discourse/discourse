class Admin::DashboardNextController < Admin::AdminController
  def index
    data = AdminDashboardNextIndexData.fetch_cached_stats

    if SiteSetting.version_checks?
      data.merge!(version_check: DiscourseUpdates.check_version.as_json)
    end

    render json: data
  end

  def moderation; end
  def security; end
  def reports; end

  def general
    render json: AdminDashboardNextGeneralData.fetch_cached_stats
  end
end
