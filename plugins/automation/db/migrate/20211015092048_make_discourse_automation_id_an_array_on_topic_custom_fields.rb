# frozen_string_literal: true

class MakeDiscourseAutomationIdAnArrayOnTopicCustomFields < ActiveRecord::Migration[5.2]
  def change
    # there's no ON CONFLICT for UPDATE/SET,
    # so it's safer to remove possible duplicates first
    DB.exec(<<~SQL)
        DELETE FROM topic_custom_fields a
        USING topic_custom_fields b
        WHERE a.ctid != b.ctid
        AND a.value = b.value
        AND a.name = 'discourse_automation_id'
        AND b.name = 'discourse_automation_id'
        AND a.topic_id = b.topic_id
        AND a.id > b.id
      SQL

    DB.exec(<<~SQL)
        UPDATE topic_custom_fields
        SET name = 'discourse_automation_ids'
        WHERE name = 'discourse_automation_id'
      SQL

    add_index :topic_custom_fields,
              %i[topic_id value],
              unique: true,
              where: "name = 'discourse_automation_ids'",
              name: :idx_topic_custom_fields_discourse_automation_unique_id_partial
  end
end
