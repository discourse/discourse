class Admin::DashboardController < Admin::AdminController

  caches_action :index, expires_in: 1.hour

  def index
    render_json_dump(AdminDashboardData.fetch_all)
  end

  def problems
    render_json_dump({problems: AdminDashboardData.fetch_problems})
  end
end