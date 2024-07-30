# frozen_string_literal: true

class MoveExistingTriggersToFields < ActiveRecord::Migration[6.1]
  def create_field(automation_id, component, name, metadata)
    DB.exec(
      <<~SQL,
      INSERT INTO discourse_automation_fields (automation_id, component, name, metadata, target, created_at, updated_at)
      VALUES (:automation_id, :component, :name, :metadata, 'trigger', :created_at, :created_at)
    SQL
      automation_id: automation_id,
      component: component,
      name: name,
      metadata: metadata.to_json,
      created_at: Time.zone.now,
    )
  end

  def change
    DB
      .query("SELECT name,automation_id,metadata FROM discourse_automation_triggers")
      .each do |trigger|
        trigger.name = "point_in_time" if trigger.name == "point-in-time"

        DB.exec(<<~SQL, automation_id: trigger.automation_id, trigger: trigger.name)
        UPDATE discourse_automation_automations
        SET trigger = :trigger
        WHERE id = :automation_id
      SQL

        trigger.metadata.each do |key, value|
          if key == "group_ids" && trigger.name == "user_added_to_group"
            create_field(trigger.automation_id, "group", "joined_group", { group_id: value })
          end

          if key == "execute_at" && trigger.name == "point_in_time"
            create_field(trigger.automation_id, "date", "execute_at", { date: value })
          end

          if key == "category_id" && trigger.name == "post_created_edited"
            create_field(
              trigger.automation_id,
              "category",
              "restricted_category",
              { category_id: value },
            )
          end

          if key == "topic" && trigger.name == "topic"
            create_field(trigger.automation_id, "topic", "restricted_topic", { topic_id: value })
          end
        end
      end

    execute <<~SQL
      DROP TABLE IF EXISTS discourse_automation_triggers;
    SQL
  end
end
