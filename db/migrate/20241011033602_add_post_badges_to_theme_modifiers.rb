# frozen_string_literal: true
class AddPostBadgesToThemeModifiers < ActiveRecord::Migration[7.1]
  def change
    add_column :theme_modifier_sets, :serialize_post_user_badges, :string, array: true
    add_column :theme_modifier_sets, :theme_setting_modifiers, :jsonb
  end
end
