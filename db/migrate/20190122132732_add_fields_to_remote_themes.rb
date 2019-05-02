# frozen_string_literal: true

class AddFieldsToRemoteThemes < ActiveRecord::Migration[5.2]
  def change
    add_column :remote_themes, :authors, :string
    add_column :remote_themes, :theme_version, :string
    add_column :remote_themes, :minimum_discourse_version, :string
    add_column :remote_themes, :maximum_discourse_version, :string
  end
end
