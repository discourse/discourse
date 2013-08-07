class Admin::StaffActionLogsController < Admin::AdminController

  def index
    staff_actions = StaffActionLog.limit(50).order('created_at desc').to_a
    render_serialized(staff_actions, StaffActionLogSerializer)
  end

end
