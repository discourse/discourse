# frozen_string_literal: true

Migrations::Database::Schema.table :user_emails do
  primary_key :user_id, :email

  include :email, :primary, :user_id, :created_at

  ignore :id, :normalized_email
end
