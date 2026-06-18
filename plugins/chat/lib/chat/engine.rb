# frozen_string_literal: true

module Chat
  HAS_CHAT_ENABLED = "has_chat_enabled"
  LAST_CHAT_CHANNEL_ID = "last_chat_channel_id"

  ONEBOX_TEMPLATE_PATH = Rails.root.join("plugins/chat/lib/onebox/templates")
  MESSAGE_ONEBOX_TEMPLATE_PATH = ONEBOX_TEMPLATE_PATH.join("discourse_chat_message.mustache")
  CHANNEL_ONEBOX_TEMPLATE_PATH = ONEBOX_TEMPLATE_PATH.join("discourse_chat_channel.mustache")
  THREAD_ONEBOX_TEMPLATE_PATH = ONEBOX_TEMPLATE_PATH.join("discourse_chat_thread.mustache")
  private_constant :ONEBOX_TEMPLATE_PATH,
                   :MESSAGE_ONEBOX_TEMPLATE_PATH,
                   :CHANNEL_ONEBOX_TEMPLATE_PATH,
                   :THREAD_ONEBOX_TEMPLATE_PATH

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

  def self.anonymous_public_channel_access_allowed?
    SiteSetting.enable_public_channels &&
      allowed_group_ids.include?(Group::AUTO_GROUPS[:anonymous_users])
  end

  def self.message_onebox_template
    return File.read(MESSAGE_ONEBOX_TEMPLATE_PATH) if Rails.env.development?

    @message_onebox_template ||= File.read(MESSAGE_ONEBOX_TEMPLATE_PATH)
  end

  def self.channel_onebox_template
    return File.read(CHANNEL_ONEBOX_TEMPLATE_PATH) if Rails.env.development?

    @channel_onebox_template ||= File.read(CHANNEL_ONEBOX_TEMPLATE_PATH)
  end

  def self.thread_onebox_template
    return File.read(THREAD_ONEBOX_TEMPLATE_PATH) if Rails.env.development?

    @thread_onebox_template ||= File.read(THREAD_ONEBOX_TEMPLATE_PATH)
  end
end
