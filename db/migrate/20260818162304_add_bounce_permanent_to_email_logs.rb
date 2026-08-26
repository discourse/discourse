# frozen_string_literal: true

class AddBouncePermanentToEmailLogs < ActiveRecord::Migration[8.0]
  def change
    # deliberately nullable with no default: NULL means the bounce was recorded
    # before the severity was tracked, which is what keeps those rows out of the
    # escalation in `EmailLog#claim_bounce`
    add_column :email_logs, :bounce_permanent, :boolean
  end
end
