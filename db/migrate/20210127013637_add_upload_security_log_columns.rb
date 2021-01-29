# frozen_string_literal: true

class AddUploadSecurityLogColumns < ActiveRecord::Migration[6.0]
  def change
    add_column :uploads, :security_last_changed_at, :datetime, null: true
    add_column :uploads, :security_last_changed_reason, :string, null: true
  end
end
