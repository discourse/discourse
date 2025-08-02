# frozen_string_literal: true

class AddPrivateKeyToRemoteTheme < ActiveRecord::Migration[5.1]
  def change
    add_column :remote_themes, :private_key, :text
  end
end
