# frozen_string_literal: true
class AddOwnerToDrafts < ActiveRecord::Migration[6.0]
  def change
    add_column :drafts, :owner, :string
  end
end
