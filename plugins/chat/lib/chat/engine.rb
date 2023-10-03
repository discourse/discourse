# frozen_string_literal: true

module ::Chat
  HAS_CHAT_ENABLED = "has_chat_enabled"

  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace Chat
    config.autoload_paths << File.join(config.root, "lib")
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
end
