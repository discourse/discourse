# frozen_string_literal: true
class AddSerializeTopicOpLikesDataThemeModifier < ActiveRecord::Migration[7.2]
  def change
    add_column :theme_modifier_sets, :serialize_topic_op_likes_data, :boolean, null: true
  end
end
