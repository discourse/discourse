# frozen_string_literal: true

Migrations::Tooling::Schema.table :muted_users do
  primary_key :user_id, :muted_user_id

  ignore :id
end
