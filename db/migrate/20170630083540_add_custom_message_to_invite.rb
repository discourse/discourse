# frozen_string_literal: true

class AddCustomMessageToInvite < ActiveRecord::Migration[4.2]
  def change
    add_column :invites, :custom_message, :text
  end
end
