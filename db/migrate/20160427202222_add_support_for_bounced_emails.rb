# frozen_string_literal: true

class AddSupportForBouncedEmails < ActiveRecord::Migration[4.2]
  def change
    add_column :email_logs, :bounced, :boolean, null: false, default: false
    add_column :incoming_emails, :is_bounce, :boolean, null: false, default: false
    add_column :user_stats, :bounce_score, :integer, null: false, default: 0
    add_column :user_stats, :reset_bounce_score_after, :datetime
  end
end
