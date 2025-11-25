# frozen_string_literal: true

module DiscourseDataExplorer
  class BulkActionLog < ActiveRecord::Base
    self.table_name = "data_explorer_bulk_action_logs"

    belongs_to :query, class_name: "DiscourseDataExplorer::Query"

    validates :query_id, presence: true
    validates :executed_at, presence: true
    validates :action_type, presence: true
    validates :total_rows, numericality: { greater_than_or_equal_to: 0 }
    validates :success_count, numericality: { greater_than_or_equal_to: 0 }
    validates :error_count, numericality: { greater_than_or_equal_to: 0 }

    def self.log_execution(
      query_id:,
      action_type:,
      total_rows:,
      success_count:,
      error_count:,
      errors_detail: [],
      automation_id: nil
    )
      create!(
        query_id: query_id,
        automation_id: automation_id,
        action_type: action_type,
        executed_at: Time.zone.now,
        total_rows: total_rows,
        success_count: success_count,
        error_count: error_count,
        errors_detail: errors_detail,
      )
    end
  end
end
