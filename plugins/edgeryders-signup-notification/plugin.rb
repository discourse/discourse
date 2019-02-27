# name: EdgerydersSignupNotification
# about:
# version: 0.1
# authors: damingo
# url: https://github.com/damingo


register_asset "stylesheets/common/edgeryders-signup-notification.scss"


enabled_site_setting :edgeryders_signup_notification_enabled

PLUGIN_NAME ||= "EdgerydersSignupNotification".freeze

after_initialize do

  # see lib/plugin/instance.rb for the methods available in this context


  module ::EdgerydersSignupNotification
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace EdgerydersSignupNotification
    end
  end


  DiscourseEvent.on(:user_created) do |user|
    # Users can simply set the notification level of the posts thread accordingly ("Watching" to get immediate
    # e-mail notifications, "Tracking" to only get in-site and desktop notifications).
    if SiteSetting.edgeryders_signup_notification_enabled?
      if topic = Topic.find_by(id: SiteSetting.edgeryders_signup_notification_topic_id)
        manager = NewPostManager.new(
          Discourse.system_user,
          raw: "We're glad to welcome [#{user.username}](/u/#{user.username}) to our community.",
          topic_id: topic.id
        )
        manager.perform
      end
    end
  end


  require_dependency "application_controller"
  class EdgerydersSignupNotification::ActionsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_logged_in

    def list
      render json: success_json
    end
  end

  EdgerydersSignupNotification::Engine.routes.draw do
    get "/list" => "actions#list"
  end

  Discourse::Application.routes.append do
    mount ::EdgerydersSignupNotification::Engine, at: "/edgeryders-signup-notification"
  end

end
