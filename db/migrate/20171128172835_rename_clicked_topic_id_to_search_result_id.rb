# frozen_string_literal: true

class RenameClickedTopicIdToSearchResultId < ActiveRecord::Migration[5.1]
  def up
    rename_column :search_logs, :clicked_topic_id, :search_result_id
    add_column :search_logs, :search_result_type, :integer, null: true

    execute "UPDATE search_logs SET search_result_type = 1 WHERE search_result_id is NOT NULL"
  end

  def down
    rename_column :search_logs, :search_result_id, :clicked_topic_id
    remove_column :search_logs, :search_result_type
  end
end
