require 'administrate/base_dashboard'

class UserDashboard < Administrate::BaseDashboard


  # Overwrite this method to customize how tags are displayed
  # across all pages of the admin dashboard.
  def display_resource(user)
    user.username
  end

end
