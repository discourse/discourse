# frozen_string_literal: true

# name: discourse-presence
# about: Show which users are writing a reply to a topic
# version: 1.0
# authors: André Pereira, David Taylor
# url: https://github.com/discourse/discourse/tree/master/plugins/discourse-presence

enabled_site_setting :presence_enabled
hide_plugin if self.respond_to?(:hide_plugin)

register_asset 'stylesheets/presence.scss'

PLUGIN_NAME ||= -"discourse-presence"

after_initialize do

  module ::Presence
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace Presence
    end
  end

  require_dependency "application_controller"

  class Presence::PresencesController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in
    before_action :ensure_presence_enabled

    def handle_message
      topic_id = permitted_params[:topic_id]
      topic = Topic.find_by(id: topic_id)
      guardian.ensure_can_see!(topic)

      MessageBus.publish(
        "/presence/#{topic_id}",
        {
          user: BasicUserSerializer.new(current_user, root: false).as_json,
          state: permitted_params[:state]
        },
        group_ids: topic.secure_group_ids,
      )

      render json: success_json
    end

    private

    def ensure_presence_enabled
      if !SiteSetting.presence_enabled ||
         current_user.user_option.hide_profile_and_presence?

        raise Discourse::NotFound
      end
    end

    def permitted_params
      params.permit(
        :state,
        :topic_id,
      )
    end
  end

  Presence::Engine.routes.draw do
    post '/publish' => 'presences#handle_message'
  end

  Discourse::Application.routes.append do
    mount ::Presence::Engine, at: '/presence'
  end

end
