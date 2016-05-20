class ShortenTopicCustomFieldsIndex < ActiveRecord::Migration
  def up
    remove_index :topic_custom_fields, :value
    add_index :topic_custom_fields, [:value, :name],
                name: 'topic_custom_fields_value_key_idx',
                where: 'value IS NOT NULL AND char_length(value) < 400'
  end
  def down
    remove_index :topic_custom_fields, :value, name: 'topic_custom_fields_value_key_idx'
    add_index :topic_custom_fields, :value
  end
end
