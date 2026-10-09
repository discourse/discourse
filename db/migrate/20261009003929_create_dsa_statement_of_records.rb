# frozen_string_literal: true
class CreateDsaStatementOfRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :dsa_statement_of_records do |t|
      t.bigint :reviewable_id, null: false
      t.string :decision_key, null: false
      t.string :action_name, null: false
      t.string :target_type, null: false
      t.bigint :target_id, null: false
      t.integer :actor_id
      t.integer :recipient_id
      t.integer :status, null: false, default: 0
      t.string :puid, null: false
      t.jsonb :payload, null: false, default: {}
      t.jsonb :content, null: false, default: {}
      t.datetime :reversed_at
      t.timestamps
    end

    add_index :dsa_statement_of_records, :puid, unique: true
    add_index :dsa_statement_of_records, %i[reviewable_id decision_key]
    add_index :dsa_statement_of_records,
              %i[decision_key target_type target_id],
              unique: true,
              name: "index_dsa_records_on_decision_and_target"
  end
end
