class StaffActionLogSerializer < ApplicationSerializer
  attributes :action_name,
             :details,
             :context,
             :ip_address,
             :email,
             :created_at

  has_one :staff_user,  serializer: BasicUserSerializer, embed: :objects
  has_one :target_user, serializer: BasicUserSerializer, embed: :objects

  def action_name
    StaffActionLog.actions.key(object.action).to_s
  end
end