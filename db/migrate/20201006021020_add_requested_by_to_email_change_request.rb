# frozen_string_literal: true

class AddRequestedByToEmailChangeRequest < ActiveRecord::Migration[6.0]
  def up
    add_column :email_change_requests, :requested_by_user_id, :integer, null: true

    DB.exec(
      "CREATE INDEX IF NOT EXISTS idx_email_change_requests_on_requested_by ON email_change_requests(requested_by_user_id)",
    )
  end

  def down
    remove_column :email_change_requests, :requested_by_user_id
  end
end
