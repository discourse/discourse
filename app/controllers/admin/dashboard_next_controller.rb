require 'disk_space'

class Admin::DashboardNextController < Admin::AdminController
  def index
    dashboard_data = AdminDashboardNextData.fetch_cached_stats
    dashboard_data.merge!(version_check: DiscourseUpdates.check_version.as_json) if SiteSetting.version_checks?
    dashboard_data[:disk_space] = DiskSpace.cached_stats if SiteSetting.enable_backups
    render json: dashboard_data
  end
end
