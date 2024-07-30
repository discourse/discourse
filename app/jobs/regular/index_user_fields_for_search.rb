# frozen_string_literal: true

class Jobs::IndexUserFieldsForSearch < Jobs::Base
  def execute(args)
    user_field_id = args[:user_field_id]
    SearchIndexer.queue_users_reindex(
      UserCustomField.where(name: "user_field_#{user_field_id}").pluck(:user_id),
    )
  end
end
