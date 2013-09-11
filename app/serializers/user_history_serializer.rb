class UserHistorySerializer < ApplicationSerializer
  attributes :action_name,
             :details,
             :context,
             :ip_address,
             :email,
             :created_at,
             :subject,
             :previous_value,
             :new_value

  has_one :acting_user, serializer: BasicUserSerializer, embed: :objects
  has_one :target_user, serializer: BasicUserSerializer, embed: :objects

  def action_name
    UserHistory.actions.key(object.action).to_s
  end

  def new_value
    if object.new_value
      object.new_value_is_json? ? ::JSON.parse(object.new_value) : object.new_value
    else
      nil
    end
  end

  def previous_value
    if object.previous_value
      object.previous_value_is_json? ? ::JSON.parse(object.previous_value) : object.previous_value
    else
      nil
    end
  end
end