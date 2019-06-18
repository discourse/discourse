# frozen_string_literal: true

class AlterReplyKeyOnEmailLogs < ActiveRecord::Migration[5.2]
  def up
    change_column :email_logs, :reply_key, 'uuid USING reply_key::uuid'
  end

  def down
    change_column :email_logs, :reply_key, :string
  end
end
