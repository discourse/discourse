# frozen_string_literal: true

# name: discourse-presence
# about: Show which users are writing a reply to a topic
# version: 2.0
# authors: André Pereira, David Taylor, tgxworld
# url: https://github.com/discourse/discourse/tree/master/plugins/discourse-presence

enabled_site_setting :presence_enabled
hide_plugin if self.respond_to?(:hide_plugin)

register_asset 'stylesheets/presence.scss'

PLUGIN_NAME ||= -"discourse-presence"

after_initialize do

  MessageBus.register_client_message_filter('/presence/') do |message|
    published_at = message.data["published_at"]

    if published_at
      (Time.zone.now.to_i - published_at) <= ::Presence::MAX_BACKLOG_AGE_SECONDS
    else
      false
    end
  end

  module ::Presence
    MAX_BACKLOG_AGE_SECONDS = 10

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

    EDITING_STATE = 'editing'
    REPLYING_STATE = 'replying'
    CLOSED_STATE = 'closed'

    def handle_message
      [:state, :topic_id].each do |key|
        raise ActionController::ParameterMissing.new(key) unless params.key?(key)
      end

      topic_id = permitted_params[:topic_id]
      topic = Topic.find_by(id: topic_id)

      raise Discourse::InvalidParameters.new(:topic_id) unless topic
      guardian.ensure_can_see!(topic)

      post = nil

      if (permitted_params[:post_id])
        if (permitted_params[:state] != EDITING_STATE)
          raise Discourse::InvalidParameters.new(:state)
        end

        post = Post.find_by(id: permitted_params[:post_id])
        raise Discourse::InvalidParameters.new(:topic_id) unless post

        guardian.ensure_can_edit!(post)
      end

      opts = {
        max_backlog_age: Presence::MAX_BACKLOG_AGE_SECONDS
      }

      if permitted_params[:staff_only]
        opts[:group_ids] = [Group::AUTO_GROUPS[:staff]]
      else
        case permitted_params[:state]
        when EDITING_STATE
          opts[:group_ids] = [Group::AUTO_GROUPS[:staff]]

          if !post.locked? && !permitted_params[:is_whisper]
            opts[:user_ids] = [post.user_id]

            if topic.private_message?
              if post.wiki
                opts[:user_ids] = opts[:user_ids].concat(
                  topic.allowed_users.where(
                    "trust_level >= ? AND NOT admin OR moderator",
                    SiteSetting.min_trust_to_edit_wiki_post
                  ).pluck(:id)
                )

                opts[:user_ids].uniq!

                # Ignore trust level and just publish to all allowed groups since
                # trying to figure out which users in the allowed groups have
                # the necessary trust levels can lead to a large array of user ids
                # if the groups are big.
                opts[:group_ids] = opts[:group_ids].concat(
                  topic.allowed_groups.pluck(:id)
                )
              end
            else
              if post.wiki
                opts[:group_ids] << Group::AUTO_GROUPS[:"trust_level_#{SiteSetting.min_trust_to_edit_wiki_post}"]
              elsif SiteSetting.trusted_users_can_edit_others?
                opts[:group_ids] << Group::AUTO_GROUPS[:trust_level_4]
              end
            end
          end
        when REPLYING_STATE
          if permitted_params[:is_whisper]
            opts[:group_ids] = [Group::AUTO_GROUPS[:staff]]
          elsif topic.private_message?
            opts[:user_ids] = topic.allowed_users.pluck(:id)

            opts[:group_ids] = [Group::AUTO_GROUPS[:staff]].concat(
              topic.allowed_groups.pluck(:id)
            )
          else
            opts[:group_ids] = topic.secure_group_ids
          end
        when CLOSED_STATE
          if topic.private_message?
            opts[:user_ids] = topic.allowed_users.pluck(:id)

            opts[:group_ids] = [Group::AUTO_GROUPS[:staff]].concat(
              topic.allowed_groups.pluck(:id)
            )
          else
            opts[:group_ids] = topic.secure_group_ids
          end
        end
      end

      payload = {
        user: BasicUserSerializer.new(current_user, root: false).as_json,
        state: permitted_params[:state],
        is_whisper: permitted_params[:is_whisper].present?,
        published_at: Time.zone.now.to_i
      }

      if (post_id = permitted_params[:post_id]).present?
        payload[:post_id] = post_id
      end

      MessageBus.publish("/presence/#{topic_id}", payload, opts)

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
      params.permit(:state, :topic_id, :post_id, :is_whisper, :staff_only)
    end
  end

  Presence::Engine.routes.draw do
    post '/publish' => 'presences#handle_message'
  end

  Discourse::Application.routes.append do
    mount ::Presence::Engine, at: '/presence'
  end

end
