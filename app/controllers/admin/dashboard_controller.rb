
class Admin::DashboardController < Admin::AdminController

  def index
    render_json_dump({
      reports: ['visits', 'signups', 'topics', 'posts', 'flags', 'users_by_trust_level', 'likes', 'emails'].map { |type| Report.find(type) },
      total_users: User.count
    }.merge(
      SiteSetting.version_checks? ? {version_check: DiscourseUpdates.check_version} : {}
    ))
  end

end