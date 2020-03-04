# frozen_string_literal: true
class AddThemeModifierSet < ActiveRecord::Migration[6.0]
  def change
    create_table(:theme_modifier_sets) do |t|
      t.references :theme, index: { unique: true }, null: false
      t.column :serialize_topic_excerpts, :boolean
      t.column :csp_extensions, :string, array: true
      t.column :svg_icons, :string, array: true
    end
  end
end
