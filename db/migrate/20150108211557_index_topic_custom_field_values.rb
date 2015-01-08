class IndexTopicCustomFieldValues < ActiveRecord::Migration
  def change
    add_index :topic_custom_fields, :value
  end
end
