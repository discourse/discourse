# frozen_string_literal: true
class AddReasonToAiSpamLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_spam_logs, :reason, :text
  end
end
