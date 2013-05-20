class Admin::DashboardController < Admin::AdminController

  def index
    # see https://github.com/rails/rails/issues/8167
    # TODO: after upgrading to Rails 4, try to remove "if cache_classes"
    if Discourse::Application.config.cache_classes
      dashboard_data = Rails.cache.fetch("admin-dashboard-data-#{Discourse::VERSION::STRING}", expires_in: 1.hour) do
        AdminDashboardData.fetch_all.as_json
      end
      render json: dashboard_data
    else
      render_json_dump AdminDashboardData.fetch_all
    end
  end

  def problems
    render_json_dump({problems: AdminDashboardData.fetch_problems})
  end
end