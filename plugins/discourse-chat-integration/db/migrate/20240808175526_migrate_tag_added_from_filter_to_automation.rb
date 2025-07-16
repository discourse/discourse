# frozen_string_literal: true

# The next migration file is a migration that migrates the tag_added filter to an automation.
# this one uses ActiveRecord which is not recommended for migrations.

class MigrateTagAddedFromFilterToAutomation < ActiveRecord::Migration[7.1]
  def up
    # if defined?(DiscourseAutomation) &&
    #      DiscourseChatIntegration::Channel.with_provider("slack").exists?
    #   begin
    #     DiscourseChatIntegration::Rule
    #       .where("value::json->>'filter'=?", "tag_added")
    #       .each do |rule|
    #         channel_id = rule.value["channel_id"]
    #         channel_name =
    #           DiscourseChatIntegration::Channel.find(channel_id).value["data"]["identifier"] # it _must_ have a channel_id

    #         category_id = rule.value["category_id"]
    #         tags = rule.value["tags"]

    #         automation =
    #           DiscourseAutomation::Automation.new(
    #             script: "send_slack_message",
    #             trigger: "topic_tags_changed",
    #             name: "When tags change in topic",
    #             enabled: true,
    #             last_updated_by_id: Discourse.system_user.id,
    #           )

    #         automation.save!

    #         # Triggers:
    #         # Watching categories

    #         metadata = (category_id ? { "value" => [category_id] } : {})

    #         automation.upsert_field!(
    #           "watching_categories",
    #           "categories",
    #           metadata,
    #           target: "trigger",
    #         )

    #         # Watching tags

    #         metadata = (tags ? { "value" => tags } : {})

    #         automation.upsert_field!("watching_tags", "tags", metadata, target: "trigger")

    #         # Script options:
    #         # Message
    #         automation.upsert_field!(
    #           "message",
    #           "message",
    #           { "value" => "${ADDED_AND_REMOVED}" },
    #           target: "script",
    #         )

    #         # URL
    #         automation.upsert_field!(
    #           "url",
    #           "text",
    #           { "value" => Discourse.current_hostname },
    #           target: "script",
    #         )

    #         # Channel
    #         automation.upsert_field!(
    #           "channel",
    #           "text",
    #           { "value" => channel_name },
    #           target: "script",
    #         )
    #       end
    #   rescue StandardError
    #     Rails.logger.warn("Failed to migrate tag_added rules to automations")
    #   end
    # end
  end

  def down
    # if defined?(DiscourseAutomation) &&
    #      DiscourseChatIntegration::Channel.with_provider("slack").exists?
    #   DiscourseAutomation::Automation
    #     .where(script: "send_slack_message", trigger: "topic_tags_changed")
    #     .each do |automation|
    #       # if is the same name as created and message is the same
    #       if automation.name == "When tags change in topic" &&
    #            automation.fields.where(name: "message").first.metadata["value"] ==
    #              "${ADDED_AND_REMOVED}"
    #         automation.destroy!
    #       end
    #     end
    # end
  end
end
