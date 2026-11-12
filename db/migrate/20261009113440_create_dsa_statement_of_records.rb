# frozen_string_literal: true

class CreateDsaStatementOfRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :dsa_statement_of_records, id: :uuid do |table|
      table.bigint :reviewable_id, null: false
      table.integer :status, null: false, default: 0
      table.jsonb :payload, null: false
      table.timestamps null: false
    end
    add_index :dsa_statement_of_records, :reviewable_id
  end
end
