# frozen_string_literal: true

class AllowNullOldEmailOnEmailChangeRequests < ActiveRecord::Migration[6.0]
  def up
    change_column :email_change_requests, :old_email, :string, null: true
  end

  def down
    change_column :email_change_requests, :old_email, :string, null: false
  end
end
