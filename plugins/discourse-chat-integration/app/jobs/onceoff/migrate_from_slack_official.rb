# frozen_string_literal: true

module Jobs
  class DiscourseChatMigrateFromSlackOfficial < ::Jobs::Onceoff
    def execute_onceoff(args)
      slack_installed = PluginStoreRow.where(plugin_name: "discourse-slack-official").exists?

      if slack_installed
        already_setup_rules = DiscourseChatIntegration::Channel.with_provider("slack").exists?

        already_setup_sitesettings =
          SiteSetting.chat_integration_slack_enabled ||
            SiteSetting.chat_integration_slack_access_token.present? ||
            SiteSetting.chat_integration_slack_incoming_webhook_token.present? ||
            SiteSetting.chat_integration_slack_outbound_webhook_url.present?

        if !already_setup_rules && !already_setup_sitesettings
          ActiveRecord::Base.transaction do
            migrate_settings
            migrate_data
            is_slack_enabled = site_settings_value("slack_enabled")

            if is_slack_enabled
              slack_enabled = SiteSetting.find_by(name: "slack_enabled")
              slack_enabled.update!(value: "f")

              SiteSetting.chat_integration_slack_enabled = true
              SiteSetting.chat_integration_enabled = true
            end
          end
        end
      end
    end

    def migrate_data
      rows = []
      PluginStoreRow
        .where(plugin_name: "discourse-slack-official")
        .where("key ~* :pat", pat: "^category_.*")
        .each do |row|
          PluginStore
            .cast_value(row.type_name, row.value)
            .each do |rule|
              category_id =
                if row.key == "category_*"
                  nil
                else
                  row.key.gsub!("category_", "")
                  row.key.to_i
                end

              next if !category_id.nil? && !Category.exists?(id: category_id)

              valid_tags = []
              valid_tags = Tag.where(name: rule[:tags]).pluck(:name) if rule[:tags]

              rows << {
                category_id: category_id,
                channel: rule[:channel],
                filter: rule[:filter],
                tags: valid_tags,
              }
            end
        end

      rows.each do |row|
        # Load an existing channel with this identifier. If none, create it
        row[:channel] = "##{row[:channel]}" unless row[:channel].start_with?("#")
        channel =
          DiscourseChatIntegration::Channel
            .with_provider("slack")
            .with_data_value("identifier", row[:channel])
            .first
        if !channel
          channel =
            DiscourseChatIntegration::Channel.create(
              provider: "slack",
              data: {
                identifier: row[:channel],
              },
            )
          if !channel.id
            Rails.logger.warn("Error creating channel for #{row}")
            next
          end
        end

        # Create the rule, with clever logic for avoiding duplicates
        success =
          DiscourseChatIntegration::Helper.smart_create_rule(
            channel: channel,
            filter: row[:filter],
            category_id: row[:category_id],
            tags: row[:tags],
          )
      end
    end

    private

    def migrate_settings
      if !(slack_access_token = site_settings_value("slack_access_token")).nil?
        SiteSetting.chat_integration_slack_access_token = slack_access_token
      end

      if !(slack_incoming_webhook_token = site_settings_value("slack_incoming_webhook_token")).nil?
        SiteSetting.chat_integration_slack_incoming_webhook_token = slack_incoming_webhook_token
      end

      if !(
           slack_discourse_excerpt_length = site_settings_value("slack_discourse_excerpt_length")
         ).nil?
        SiteSetting.chat_integration_slack_excerpt_length = slack_discourse_excerpt_length
      end

      if !(slack_outbound_webhook_url = site_settings_value("slack_outbound_webhook_url")).nil?
        SiteSetting.chat_integration_slack_outbound_webhook_url = slack_outbound_webhook_url
      end

      if !(slack_icon_url = site_settings_value("slack_icon_url")).nil?
        SiteSetting.chat_integration_slack_icon_url = slack_icon_url
      end

      if !(post_to_slack_window_secs = site_settings_value("post_to_slack_window_secs")).nil?
        SiteSetting.chat_integration_delay_seconds = post_to_slack_window_secs
      end

      if !(slack_discourse_username = site_settings_value("slack_discourse_username")).nil?
        username = User.find_by(username: slack_discourse_username.downcase)&.username
        SiteSetting.chat_integration_discourse_username =
          (username || Discourse.system_user.username)
      end
    end

    def site_settings_value(name)
      value = SiteSetting.find_by(name: name)&.value

      if value == "t"
        value = true
      elsif value == "f"
        value = false
      end

      value
    end
  end
end
