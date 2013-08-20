class Admin::StaffActionLogsController < Admin::AdminController

  def index
    staff_action_logs = StaffActionLog.with_filters(params.slice(:action_name, :staff_user, :target_user, :subject)).limit(200).order('id DESC').includes(:staff_user, :target_user).to_a
    render_serialized(staff_action_logs, StaffActionLogSerializer)
  end

end
