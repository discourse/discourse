class BasicGroupHistorySerializer < ApplicationSerializer
  attributes :action,
             :subject,
             :prev_value,
             :new_value,
             :created_at

  has_one :acting_user, embed: :objects, serializer: BasicUserSerializer
  has_one :target_user, embed: :objects, serializer: BasicUserSerializer

  def action
    GroupHistory.actions[object.action]
  end
end
