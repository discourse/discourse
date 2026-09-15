# frozen_string_literal: true
class AddPluginNameToBadges < ActiveRecord::Migration[8.0]
  def change
    add_column :badges, :plugin_name, :string
  end
end
