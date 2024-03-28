# frozen_string_literal: true

class AddCustomHomepageThemeModifiers < ActiveRecord::Migration[7.0]
  def change
    add_column :theme_modifier_sets, :custom_homepage, :boolean, null: true
  end
end
