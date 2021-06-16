# frozen_string_literal: true

class AddSmtpGroupIdToEmailLog < ActiveRecord::Migration[6.1]
  def change
    add_column :email_logs, :smtp_group_id, :integer, null: true, index: true
  end
end
