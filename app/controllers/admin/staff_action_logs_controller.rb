class Admin::StaffActionLogsController < Admin::AdminController

  def index
    staff_action_logs = UserHistory.with_filters(params.slice(:action_name, :acting_user, :target_user, :subject)).only_staff_actions.limit(200).order('id DESC').includes(:acting_user, :target_user).to_a
    render_serialized(staff_action_logs, UserHistorySerializer)
  end

end
