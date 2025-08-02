# frozen_string_literal: true

class AddBounceErrorCodeToEmailLog < ActiveRecord::Migration[6.1]
  def change
    add_column :email_logs, :bounce_error_code, :string, null: true
  end
end
