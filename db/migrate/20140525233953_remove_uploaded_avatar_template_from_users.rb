# frozen_string_literal: true

class RemoveUploadedAvatarTemplateFromUsers < ActiveRecord::Migration[4.2]
  def change
    remove_column :users, :uploaded_avatar_template
  end
end
