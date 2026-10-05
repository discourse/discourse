# frozen_string_literal: true

class CreateAskAiReports < ActiveRecord::Migration[8.0]
  def change
    create_table :ask_ai_reports do |t|
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.bigint :requested_by_id, null: false
      t.integer :report_status, null: false, default: 0
      t.boolean :send_to_groups, null: false, default: false
      t.integer :total_ask_count, null: false
      t.integer :reported_ask_count, null: false
      t.bigint :topic_id
      t.timestamps
      t.bigint :selected_ask_ids, array: true, default: [], null: false
      t.text :summary, default: "", null: false
    end
    add_index :ask_ai_reports, %i[start_date end_date created_at]
    add_index :ask_ai_reports, :created_at

    create_table :ask_ai_report_subjects do |t|
      t.bigint :ask_ai_report_id, null: false
      t.string :name, null: false
      t.text :description, null: false
      t.integer :position, null: false
      t.integer :ask_count, null: false
    end
    add_index :ask_ai_report_subjects, %i[ask_ai_report_id position], unique: true

    create_table :ask_ai_report_subject_asks do |t|
      t.bigint :ask_ai_report_subject_id, null: false
      t.bigint :ask_ai_log_id, null: false
    end

    add_index :ask_ai_report_subject_asks,
              %i[ask_ai_report_subject_id ask_ai_log_id],
              unique: true,
              name: "index_ask_ai_report_subject_asks_on_subject_and_log"
    add_index :ask_ai_report_subject_asks, :ask_ai_log_id
    add_foreign_key :ask_ai_report_subject_asks, :ask_ai_report_subjects, on_delete: :cascade
    add_foreign_key :ask_ai_report_subject_asks, :ask_ai_logs, on_delete: :cascade
  end
end
