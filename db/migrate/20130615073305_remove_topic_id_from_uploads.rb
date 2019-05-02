# frozen_string_literal: true

class RemoveTopicIdFromUploads < ActiveRecord::Migration[4.2]
  def up
    remove_column :uploads, :topic_id
  end

  def down
    add_column :uploads, :topic_id, :interger, null: false, default: -1
  end
end
