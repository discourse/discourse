# frozen_string_literal: true

class AddTagToPermalink < ActiveRecord::Migration[6.0]
  def change
    add_column :permalinks, :tag_id, :integer
  end
end
