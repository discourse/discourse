# frozen_string_literal: true

class AddTargetTagIdToTags < ActiveRecord::Migration[6.0]
  def change
    add_column :tags, :target_tag_id, :integer
  end
end
