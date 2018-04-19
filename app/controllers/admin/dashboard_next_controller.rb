require 'disk_space'

class Admin::DashboardNextController < Admin::AdminController
  def index
    dashboard_data = AdminDashboardNextData.fetch_stats
    dashboard_data[:disk_space] = DiskSpace.cached_stats
    render json: dashboard_data
  end
end
