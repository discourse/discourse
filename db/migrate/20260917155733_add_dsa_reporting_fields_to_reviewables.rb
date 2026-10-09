# frozen_string_literal: true
class AddDsaReportingFieldsToReviewables < ActiveRecord::Migration[8.0]
  def change
    add_column :reviewables, :dsa_category, :string
    add_column :reviewables, :dsa_subcategory, :string
    add_column :reviewables, :dsa_subcategory_other, :string, limit: 500
    add_column :reviewables, :legal_basis, :string
    add_column :reviewables, :restriction_type, :string
    add_column :reviewables, :outcome_source, :string

    # Handled items awaiting a classification stay in the pending queue, which is counted
    # and listed constantly.
    add_index :reviewables,
              :status,
              where: "legal_basis IS NOT NULL AND dsa_category IS NULL",
              name: "index_reviewables_awaiting_dsa_classification"
  end
end
