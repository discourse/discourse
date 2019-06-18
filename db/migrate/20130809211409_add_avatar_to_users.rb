# frozen_string_literal: true

class AddAvatarToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :use_uploaded_avatar, :boolean, default: false
    add_column :users, :uploaded_avatar_template, :string
    add_column :users, :uploaded_avatar_id, :integer
  end
end
