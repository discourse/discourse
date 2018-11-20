class AddPmTopicCountToTags < ActiveRecord::Migration[5.1]
  def change
    add_column :tags, :pm_topic_count, :integer, null: false, default: 0
  end
end
