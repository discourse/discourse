# frozen_string_literal: true

class AddEmailSettingsToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :email_replied, :boolean, default: true
    add_column :users, :email_quoted, :boolean, default: true
  end
end
