# frozen_string_literal: true
class AddPurposeToEmailLoginCodes < ActiveRecord::Migration[8.0]
  def change
    add_column :email_login_codes, :purpose, :integer, default: 0, null: false
  end
end
