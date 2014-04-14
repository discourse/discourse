class Admin::StaffActionLogsController < Admin::AdminController

  def index
    staff_action_logs = UserHistory.staff_action_records(current_user, params.slice(:action_name, :acting_user, :target_user, :subject)).to_a
    render_serialized(staff_action_logs, UserHistorySerializer)
  end

end
