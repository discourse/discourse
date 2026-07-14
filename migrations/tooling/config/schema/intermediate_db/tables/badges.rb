# frozen_string_literal: true

Migrations::Tooling::Schema.table :badges do
  add_column :existing_id, :numeric

  ignore :grant_count, :system, reason: "Calculated columns"
end
