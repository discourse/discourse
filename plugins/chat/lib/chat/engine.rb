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

  def self.onebox_template
    @onebox_template ||=
      begin
        path = "#{Rails.root}/plugins/chat/lib/onebox/templates/discourse_chat.mustache"
        File.read(path)
      end
  end
end
