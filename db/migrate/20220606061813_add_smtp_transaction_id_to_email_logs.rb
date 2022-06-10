# frozen_string_literal: true

class AddSmtpTransactionIdToEmailLogs < ActiveRecord::Migration[7.0]
  def change
    add_column :email_logs, :smtp_transaction_id, :string, null: true, limit: 500, index: true
  end
end
