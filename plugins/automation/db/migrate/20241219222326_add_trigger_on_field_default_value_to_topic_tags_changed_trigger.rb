# frozen_string_literal: true
class AddTriggerOnFieldDefaultValueToTopicTagsChangedTrigger < ActiveRecord::Migration[7.2]
  def up
    create_automation_field = <<~SQL
              INSERT INTO discourse_automation_fields (automation_id, name, component, metadata, target, created_at, updated_at)
              VALUES (:automation_id, 'trigger_on', 'choices', :metadata, 'script', NOW(), NOW())
        SQL

    topic_tags_changed_enabled_automations_without_trigger_on_field = DB.query <<~SQL
      SELECT discourse_automation_automations.*
      FROM discourse_automation_automations
      WHERE discourse_automation_automations.trigger = 'topic_tags_changed'
      AND discourse_automation_automations.enabled = TRUE
      AND NOT EXISTS
        (SELECT 1
        FROM discourse_automation_fields
        WHERE automation_id = discourse_automation_automations.id
        AND name = 'trigger_on')
      SQL

    topic_tags_changed_enabled_automations_without_trigger_on_field.each do |automation|
      DB.exec(
        create_automation_field,
        automation_id: automation.id,
        metadata: { "value" => "tags_added_or_removed" }.to_json,
      )
    end
  end

  def down
    trigger_on_fields = DB.query <<~SQL
      SELECT discourse_automation_fields.*
      FROM discourse_automation_fields
      JOIN discourse_automation_automations
      ON discourse_automation_fields.automation_id = discourse_automation_automations.id
      WHERE discourse_automation_automations.trigger = 'topic_tags_changed'
      AND discourse_automation_automations.enabled = TRUE
      AND discourse_automation_fields.name = 'trigger_on'
      SQL

    trigger_on_fields.each { |field| DB.exec(<<~SQL, field_id: field.id) }
          DELETE FROM discourse_automation_fields
          WHERE id = :field_id
        SQL
  end
end
