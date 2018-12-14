class Admin::DashboardController < Admin::AdminController
  def index
    dashboard_data = AdminDashboardData.fetch_cached_stats || Jobs::DashboardStats.new.execute({})
    dashboard_data.merge!(version_check: DiscourseUpdates.check_version.as_json) if SiteSetting.version_checks?
    render json: dashboard_data
  end

  def problems
    render_json_dump(problems: AdminDashboardData.fetch_problems(check_force_https: request.ssl?))
  end
end
