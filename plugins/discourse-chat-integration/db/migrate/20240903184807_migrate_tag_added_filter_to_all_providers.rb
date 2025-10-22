# frozen_string_literal: true
class MigrateTagAddedFilterToAllProviders < ActiveRecord::Migration[7.1]
  def up
    if defined?(DiscourseAutomation)
      begin
        slack_usage_rows = DB.query <<~SQL
        SELECT plugin_store_rows.* FROM plugin_store_rows
        WHERE plugin_store_rows.type_name = 'JSON'
        AND plugin_store_rows.plugin_name = 'discourse-chat-integration'
        AND (key LIKE 'channel:%')
        AND (value::json->>'provider'='slack')
        SQL

        old_migration_delete = <<~SQL
        DELETE FROM discourse_automation_automations
        WHERE id IN (
          SELECT a.id
          FROM discourse_automation_automations a
          JOIN discourse_automation_fields f ON f.automation_id = a.id
          WHERE a.script = 'send_slack_message'
            AND a.trigger = 'topic_tags_changed'
            AND a.name = 'When tags change in topic'
            AND f.name = 'message'
            AND f.metadata->>'value' = '${ADDED_AND_REMOVED}'
        )
        SQL
        # Trash old migration
        DB.exec old_migration_delete if slack_usage_rows.count > 0

        rules_with_tag_added = <<~SQL
        SELECT value
        FROM plugin_store_rows
        WHERE plugin_name = 'discourse-chat-integration'
          AND key LIKE 'rule:%'
          AND value::json->>'filter' = 'tag_added'
        SQL

        channel_query = <<~SQL
        SELECT *
        FROM plugin_store_rows
        WHERE type_name = 'JSON'
          AND plugin_name = 'discourse-chat-integration'
          AND key LIKE 'channel:%'
          AND id = :channel_id
        LIMIT 1
        SQL

        automation_creation = <<~SQL
              INSERT INTO discourse_automation_automations (script, trigger, name, enabled, last_updated_by_id, created_at, updated_at)
              VALUES ('send_chat_integration_message', 'topic_tags_changed', 'When tags change in topic', true, -1, NOW(), NOW())
              RETURNING id
        SQL

        create_automation_field = <<~SQL
              INSERT INTO discourse_automation_fields (automation_id, name, component, metadata, target, created_at, updated_at)
              VALUES (:automation_id, :name, :component, :metadata, :target, NOW(), NOW())
        SQL

        provider_identifier_map = {
          "groupme" => "groupme_instance_name",
          "discord" => "name",
          "guilded" => "name",
          "mattermost" => "identifier",
          "matrix" => "name",
          "teams" => "name",
          "zulip" => "stream",
          "powerautomate" => "name",
          "rocketchat" => "identifier",
          "gitter" => "name",
          "telegram" => "name",
          "flowdock" => "flow_token",
          "google" => "name",
          "webex" => "name",
          "slack" => "identifier",
        }

        DB
          .query(rules_with_tag_added)
          .each do |row|
            rule = JSON.parse(row.value).with_indifferent_access

            channel =
              JSON.parse(
                DB.query(channel_query, channel_id: rule[:channel_id]).first.value,
              ).with_indifferent_access

            provider_name = channel[:provider]
            channel_name = channel[:data][provider_identifier_map[provider_name]]

            category_id = rule[:category_id]
            tags = rule[:tags]

            automation_id = DB.query(automation_creation).first.id

            # Triggers:
            # Watching categories
            metadata = (category_id ? { "value" => [category_id] } : {}).to_json
            DB.exec(
              create_automation_field,
              automation_id: automation_id,
              name: "watching_categories",
              component: "categories",
              metadata: metadata,
              target: "trigger",
            )

            # Watching tags
            metadata = (tags.present? ? { "value" => tags } : {}).to_json
            DB.exec(
              create_automation_field,
              automation_id: automation_id,
              name: "watching_tags",
              component: "tags",
              metadata: metadata,
              target: "trigger",
            )

            # Script options:
            # Provider
            DB.exec(
              create_automation_field,
              automation_id: automation_id,
              name: "provider",
              component: "choices",
              metadata: { "value" => provider_name }.to_json,
              target: "script",
            )

            # Channel name
            DB.exec(
              create_automation_field,
              automation_id: automation_id,
              name: "channel_name",
              component: "text",
              metadata: { "value" => channel_name }.to_json,
              target: "script",
            )
          end
      rescue StandardError
        puts "Error migrating tag_added filters to all providers"
      end
    end
  end

  def down
    DB.exec <<~SQL if defined?(DiscourseAutomation)
        DELETE FROM discourse_automation_automations
        WHERE script = 'send_chat_integration_message'
          AND trigger = 'topic_tags_changed'
          AND name = 'When tags change in topic'
      SQL
  end
end
