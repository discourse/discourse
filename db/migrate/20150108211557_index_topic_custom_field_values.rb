# frozen_string_literal: true

class IndexTopicCustomFieldValues < ActiveRecord::Migration[4.2]
  def change
    add_index :topic_custom_fields, :value
  end
end
