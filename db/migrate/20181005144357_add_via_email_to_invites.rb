# frozen_string_literal: true

class AddViaEmailToInvites < ActiveRecord::Migration[5.2]
  def change
    add_column :invites, :via_email, :boolean, default: false, null: false
  end
end
