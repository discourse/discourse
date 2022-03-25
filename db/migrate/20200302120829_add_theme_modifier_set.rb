# frozen_string_literal: true
class AddThemeModifierSet < ActiveRecord::Migration[6.0]
  def change
    create_table(:theme_modifier_sets) do |t|
      t.bigint :theme_id, null: false
      t.column :serialize_topic_excerpts, :boolean
      t.column :csp_extensions, :string, array: true
      t.column :svg_icons, :string, array: true
    end

    add_index :theme_modifier_sets, :theme_id, unique: true
  end
end
