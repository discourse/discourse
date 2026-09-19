# frozen_string_literal: true

Migrations::Tooling::Schema.table :user_options do
  include_all
  primary_key :user_id
end
