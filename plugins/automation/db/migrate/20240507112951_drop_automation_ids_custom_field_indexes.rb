# frozen_string_literal: true

class DropAutomationIdsCustomFieldIndexes < ActiveRecord::Migration[7.0]
  def change
    remove_index :topic_custom_fields,
                 name: :idx_topic_custom_fields_discourse_automation_unique_id_partial,
                 if_exists: true
    remove_index :user_custom_fields,
                 name: :idx_user_custom_fields_discourse_automation_unique_id_partial,
                 if_exists: true
    remove_index :post_custom_fields,
                 name: :idx_post_custom_fields_discourse_automation_unique_id_partial,
                 if_exists: true
  end
end
