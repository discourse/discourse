# frozen_string_literal: true

class AddAnonymousUserInheritanceToGroups < ActiveRecord::Migration[7.0]
  def change
    add_column :groups, :anonymous_user_inheritance, :boolean, null: false, default: false
  end
end
