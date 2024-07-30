# frozen_string_literal: true

class AddAutoResponderTriggeredIdsIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :topic_custom_fields,
              %i[topic_id value],
              unique: true,
              where: "name = 'auto_responder_triggered_ids'",
              name: :idx_topic_custom_fields_auto_responder_triggered_ids_partial
  end
end
