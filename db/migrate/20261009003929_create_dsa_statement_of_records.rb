# frozen_string_literal: true
class CreateDsaStatementOfRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :dsa_statement_of_records, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.bigint :reviewable_id, null: false
      t.integer :status, null: false, default: 0
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end

    add_index :dsa_statement_of_records, :reviewable_id
  end
end
