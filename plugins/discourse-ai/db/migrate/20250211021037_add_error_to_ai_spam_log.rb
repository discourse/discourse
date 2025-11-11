# frozen_string_literal: true
class AddErrorToAiSpamLog < ActiveRecord::Migration[7.2]
  def change
    add_column :ai_spam_logs, :error, :string, limit: 3000
  end
end
