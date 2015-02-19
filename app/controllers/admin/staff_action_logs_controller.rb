class Admin::StaffActionLogsController < Admin::AdminController

  def index
    filters = params.slice(*UserHistory.staff_filters)
    staff_action_logs = UserHistory.staff_action_records(current_user, filters).to_a
    render_serialized(staff_action_logs, UserHistorySerializer)
  end

end
