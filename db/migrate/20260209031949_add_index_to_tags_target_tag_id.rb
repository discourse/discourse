# frozen_string_literal: true
class AddIndexToTagsTargetTagId < ActiveRecord::Migration[8.0]
  def change
    add_index :tags, :target_tag_id, where: "target_tag_id IS NOT NULL"
  end
end
