# frozen_string_literal: true

Migrations::Database::Schema.table :user_associated_accounts do
  primary_key :user_id, :provider_name

  column :user_id, required: true
  column :last_used, required: false

  ignore :id, "TODO: add reason"
  ignore :credentials, "TODO: add reason"
  ignore :extra, "TODO: add reason"
end
