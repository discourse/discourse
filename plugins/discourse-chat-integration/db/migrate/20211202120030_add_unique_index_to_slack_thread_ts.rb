# frozen_string_literal: true

class AddUniqueIndexToSlackThreadTs < ActiveRecord::Migration[6.1]
  def up
    add_index :topic_custom_fields,
              %i[topic_id name],
              unique: true,
              where: "(name LIKE 'slack_thread_id_%')",
              name: "index_topic_custom_fields_on_topic_id_and_slack_thread_id"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
