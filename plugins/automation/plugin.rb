# name: discourse-automation
# about:
# version: 0.1
# authors: blake, jjaffeux
# url: https://github.com/jjaffeux/discourse-automation

register_asset "stylesheets/common/discourse-automation.scss"
enabled_site_setting :discourse_automation_enabled

PLUGIN_NAME ||= "discourse-automation".freeze

after_initialize do
  module ::DiscourseAutomation
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseAutomation
    end
  end
end
