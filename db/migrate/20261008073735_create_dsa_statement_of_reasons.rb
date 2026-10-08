# frozen_string_literal: true

class CreateDsaStatementOfReasons < ActiveRecord::Migration[8.1]
  def change
    create_table :dsa_statement_of_reasons do |t|
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
      t.string :community_rule, null: false, default: ""
      t.integer :classified_by_id
      t.datetime :classified_at
      t.string :api_environment, null: false, default: ""
      t.integer :attempts, null: false, default: 0
      t.datetime :next_attempt_at
      t.string :error_code, null: false, default: ""
      t.datetime :submitted_at
      t.string :submission_uuid, null: false, default: ""
      t.datetime :reversed_at
      t.timestamps
    end

    add_index :dsa_statement_of_reasons, :puid, unique: true
    add_index :dsa_statement_of_reasons, %i[reviewable_id decision_key]
    add_index :dsa_statement_of_reasons,
              %i[decision_key target_type target_id],
              unique: true,
              name: "index_dsa_statements_on_decision_and_target"
    add_index :dsa_statement_of_reasons,
              :reviewable_id,
              where: "(status = 0 AND classified_at IS NULL) OR status = 2",
              name: "index_dsa_statements_unfinished"
    add_index :dsa_statement_of_reasons,
              %i[next_attempt_at id],
              where: "status = 0 AND classified_at IS NOT NULL",
              name: "index_dsa_statements_pending_delivery"
  end
end
