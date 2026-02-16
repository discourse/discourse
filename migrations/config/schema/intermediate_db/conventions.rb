# frozen_string_literal: true

Migrations::Database::Schema.conventions do
  column :id do
    rename_to :original_id
    type :numeric
  end

  column :created_at do
    required false
  end

  columns_matching(/.*upload.*_id$/) { type :text }
  columns_matching(/.*_id$/) { type :numeric }

  # Globally ignored columns
  ignore_columns :updated_at
end
