# frozen_string_literal: true

Migrations::Database::Schema.table :group_users do
  primary_key :group_id, :user_id

  ignore :id, "TODO: add reason"
  ignore :first_unread_pm_at, "TODO: add reason"
end
