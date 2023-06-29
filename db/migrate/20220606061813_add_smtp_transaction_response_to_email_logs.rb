# frozen_string_literal: true

class AddSmtpTransactionResponseToEmailLogs < ActiveRecord::Migration[7.0]
  def change
    add_column :email_logs, :smtp_transaction_response, :string, null: true, limit: 500
  end
end
