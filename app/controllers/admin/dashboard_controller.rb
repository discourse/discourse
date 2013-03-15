class Admin::DashboardController < Admin::AdminController

  def index
    render_json_dump({
      reports: ['visits', 'signups', 'topics', 'posts', 'total_users', 'flags'].map { |type| Report.find(type) }
    }.merge(
      SiteSetting.version_checks? ? {version_check: DiscourseUpdates.check_version} : {}
    ))
  end

end