# frozen_string_literal: true
class AddDurationToAiApiLog < ActiveRecord::Migration[7.2]
  def change
    add_column :ai_api_audit_logs, :duration_msecs, :integer
  end
end
