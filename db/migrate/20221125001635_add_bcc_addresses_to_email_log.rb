# frozen_string_literal: true

class AddBccAddressesToEmailLog < ActiveRecord::Migration[6.1]
  def change
    add_column :email_logs, :bcc_addresses, :text, null: true
  end
end
