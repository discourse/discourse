class StaffActionLogsSerializer < ApplicationSerializer
  attributes :user_history_actions
  has_many :staff_action_logs, serializer: UserHistorySerializer, embed: :objects

  def staff_action_logs
    object[:staff_action_logs]
  end

  def user_history_actions
    object[:user_history_actions]
  end
end
