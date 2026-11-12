# frozen_string_literal: true
class AddAdminToInvites < ActiveRecord::Migration[8.0]
  def change
    add_column :invites, :admin, :boolean, default: false, null: false
  end
end
