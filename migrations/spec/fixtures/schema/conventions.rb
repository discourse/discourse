# frozen_string_literal: true

Migrations::Database::Schema.conventions do
  column :id do
    rename_to :original_id
    type :integer
    required
  end

  columns_matching(/_at$/) { type :datetime }

  ignore_columns :created_by, :updated_by
end
