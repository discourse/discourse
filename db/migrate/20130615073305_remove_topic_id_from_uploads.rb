class RemoveTopicIdFromUploads < ActiveRecord::Migration
  def up
    remove_column :uploads, :topic_id
  end

  def down
    add_column :uploads, :topic_id, :interger, null: false, default: -1
  end
end
