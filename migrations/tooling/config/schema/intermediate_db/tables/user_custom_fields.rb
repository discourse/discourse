# frozen_string_literal: true

Migrations::Tooling::Schema.table :user_custom_fields do
  primary_key :user_id, :name, :value

  column :value, required: true

  ignore :id
end
