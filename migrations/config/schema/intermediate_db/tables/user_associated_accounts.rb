# frozen_string_literal: true

Migrations::Database::Schema.table :user_associated_accounts do
  primary_key :user_id, :provider_name

  column :last_used, required: false

  ignore :credentials, :extra, :id
end
