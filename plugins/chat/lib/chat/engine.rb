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

  def self.message_onebox_template
    path = "#{Rails.root}/plugins/chat/lib/onebox/templates/discourse_chat_message.mustache"
    return File.read(path) if Rails.env.development?

    @message_onebox_template ||= File.read(path)
  end

  def self.channel_onebox_template
    path = "#{Rails.root}/plugins/chat/lib/onebox/templates/discourse_chat_channel.mustache"
    return File.read(path) if Rails.env.development?

    @channel_onebox_template ||= File.read(path)
  end

  def self.thread_onebox_template
    path = "#{Rails.root}/plugins/chat/lib/onebox/templates/discourse_chat_thread.mustache"
    return File.read(path) if Rails.env.development?

    @thread_onebox_template ||= File.read(path)
  end
end
