
class Admin::DashboardController < Admin::AdminController

  def index
    render_json_dump(AdminDashboardData.fetch)
  end

end