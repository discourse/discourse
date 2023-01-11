# frozen_string_literal: true

class AddEmailFromAliasToGroups < ActiveRecord::Migration[6.1]
  def change
    add_column :groups, :email_from_alias, :string, null: true
  end
end
