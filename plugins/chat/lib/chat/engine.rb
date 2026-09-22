# frozen_string_literal: true

module Chat
  HAS_CHAT_ENABLED = "has_chat_enabled"
  LAST_CHAT_CHANNEL_ID = "last_chat_channel_id"

  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace Chat
    config.autoload_paths << File.join(config.root, "lib")
    scheduled_job_dir = "#{config.root}/app/jobs/scheduled"
    config.to_prepare do
      Rails.autoloaders.main.eager_load_dir(scheduled_job_dir) if Dir.exist?(scheduled_job_dir)
    end
  end

  def self.allowed_group_ids
    SiteSetting.chat_allowed_groups_map
  end

  def self.message_bus_group_ids_for(group_ids)
    return group_ids if group_ids.blank? || !SiteSetting.chat_enabled
    return group_ids if (group_ids & message_bus_allowed_group_ids).blank?

    group_ids + group_ids.map { |group_id| restricted_category_message_bus_audience_id(group_id) }
  end

  def self.restricted_category_message_bus_audience_id(group_id)
    "chat-restricted-category-group-#{group_id}"
  end

  def self.message_bus_allowed_group_ids
    allowed_group_ids
      .map do |group_id|
        group_id == Group::AUTO_GROUPS[:everyone] ? Group::AUTO_GROUPS[:trust_level_0] : group_id
      end
      .uniq
  end

  def self.message_onebox_template
    @message_onebox_template ||=
      begin
        path = "#{Rails.root}/plugins/chat/lib/onebox/templates/discourse_chat_message.mustache"
        File.read(path)
      end
  end

  def self.channel_onebox_template
    @channel_onebox_template ||=
      begin
        path = "#{Rails.root}/plugins/chat/lib/onebox/templates/discourse_chat_channel.mustache"
        File.read(path)
      end
  end

  def self.thread_onebox_template
    @thread_onebox_template ||=
      begin
        path = "#{Rails.root}/plugins/chat/lib/onebox/templates/discourse_chat_thread.mustache"
        File.read(path)
      end
  end
end
