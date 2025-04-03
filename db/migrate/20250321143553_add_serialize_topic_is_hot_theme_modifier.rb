# frozen_string_literal: true

class AddSerializeTopicIsHotThemeModifier < ActiveRecord::Migration[7.2]
  def change
    add_column :theme_modifier_sets, :serialize_topic_is_hot, :boolean, null: true
  end
end
