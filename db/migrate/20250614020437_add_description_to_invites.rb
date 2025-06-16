# frozen_string_literal: true

class AddDescriptionToInvites < ActiveRecord::Migration[7.2]
  def change
    add_column :invites, :description, :string, limit: 100
  end
end
