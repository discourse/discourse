# frozen_string_literal: true

class AddClassificationToDsaStatementOfRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :dsa_statement_of_records, :classified_by_id, :bigint
    add_column :dsa_statement_of_records, :classified_at, :datetime
  end
end
