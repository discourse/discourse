# frozen_string_literal: true

module ::Chat
  HAS_CHAT_ENABLED = "has_chat_enabled"
  LAST_CHAT_CHANNEL_ID = "last_chat_channel_id"

  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace Chat
    config.autoload_paths << File.join(config.root, "lib")
    config.to_prepare do
      Rails.autoloaders.main.eager_load_dir("#{Chat::Engine.config.root}/app/jobs/scheduled")
    end
  end

  def self.allowed_group_ids
    SiteSetting.chat_allowed_groups_map
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
