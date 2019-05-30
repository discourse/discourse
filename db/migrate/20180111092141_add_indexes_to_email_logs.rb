# frozen_string_literal: true

class AddIndexesToEmailLogs < ActiveRecord::Migration[5.1]
  def change
    add_index :email_logs, :post_id
    add_index :email_logs, :topic_id
  end
end
