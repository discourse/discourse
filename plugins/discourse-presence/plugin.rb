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

  module ::Presence::PresenceManager
    MAX_BACKLOG_AGE ||= 60

    def self.get_redis_key(type, id)
      "presence:#{type}:#{id}"
    end

    def self.get_messagebus_channel(type, id)
      "/presence/#{type}/#{id}"
    end

    # return true if a key was added
    def self.add(type, id, user_id)
      key = get_redis_key(type, id)
      result = Discourse.redis.hset(key, user_id, Time.zone.now)
      Discourse.redis.expire(key, MAX_BACKLOG_AGE)
      result
    end

    # return true if a key was deleted
    def self.remove(type, id, user_id)
      key = get_redis_key(type, id)
      Discourse.redis.expire(key, MAX_BACKLOG_AGE)
      Discourse.redis.hdel(key, user_id) > 0
    end

    def self.get_users(type, id)
      user_ids = Discourse.redis.hkeys(get_redis_key(type, id)).map(&:to_i)
      User.where(id: user_ids)
    end

    def self.publish(type, id)
      users = get_users(type, id)
      serialized_users = users.map { |u| BasicUserSerializer.new(u, root: false) }
      message = { users: serialized_users, time: Time.now.to_i }
      messagebus_channel = get_messagebus_channel(type, id)

      topic = type == 'post' ? Post.find_by(id: id).topic : Topic.find_by(id: id)

      if topic.private_message?
        user_ids = User.where('admin OR moderator').pluck(:id) + topic.allowed_users.pluck(:id)
        group_ids = topic.allowed_groups.pluck(:id)

        MessageBus.publish(
          messagebus_channel,
          message.as_json,
          user_ids: user_ids,
          group_ids: group_ids,
          max_backlog_age: MAX_BACKLOG_AGE
        )
      else
        MessageBus.publish(
          messagebus_channel,
          message.as_json,
          group_ids: topic.secure_group_ids,
          max_backlog_age: MAX_BACKLOG_AGE
        )
      end

      users
    end

    def self.cleanup(type, id)
      has_changed = false

      # Delete entries older than 20 seconds
      hash = Discourse.redis.hgetall(get_redis_key(type, id))
      hash.each do |user_id, time|
        if Time.zone.now - Time.parse(time) >= 20
          has_changed |= remove(type, id, user_id)
        end
      end

      has_changed
    end

  end

  require_dependency "application_controller"

  class Presence::PresencesController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in

    ACTIONS ||= [-"edit", -"reply"].freeze

    def publish
      raise Discourse::NotFound if current_user.blank? || current_user.user_option.hide_profile_and_presence?

      data = params.permit(
        :response_needed,
        current: [:action, :topic_id, :post_id],
        previous: [:action, :topic_id, :post_id]
      )

      payload = {}

      if data[:previous] && data[:previous][:action].in?(ACTIONS)
        type = data[:previous][:post_id] ? 'post' : 'topic'
        id = data[:previous][:post_id] ? data[:previous][:post_id] : data[:previous][:topic_id]

        topic = type == 'post' ? Post.find_by(id: id)&.topic : Topic.find_by(id: id)

        if topic
          guardian.ensure_can_see!(topic)

          Presence::PresenceManager.remove(type, id, current_user.id)
          Presence::PresenceManager.cleanup(type, id)
          Presence::PresenceManager.publish(type, id)
        end
      end

      if data[:current] && data[:current][:action].in?(ACTIONS)
        type = data[:current][:post_id] ? 'post' : 'topic'
        id = data[:current][:post_id] ? data[:current][:post_id] : data[:current][:topic_id]

        topic = type == 'post' ? Post.find_by(id: id)&.topic : Topic.find_by(id: id)

        if topic
          guardian.ensure_can_see!(topic)

          Presence::PresenceManager.add(type, id, current_user.id)
          Presence::PresenceManager.cleanup(type, id)
          users = Presence::PresenceManager.publish(type, id)

          if data[:response_needed]
            messagebus_channel = Presence::PresenceManager.get_messagebus_channel(type, id)
            users ||= Presence::PresenceManager.get_users(type, id)
            payload = json_payload(messagebus_channel, users)
          end
        end
      end

      render json: payload
    end

    def json_payload(channel, users)
      {
        messagebus_channel: channel,
        messagebus_id: MessageBus.last_id(channel),
        users: users.limit(SiteSetting.presence_max_users_shown).map { |u| BasicUserSerializer.new(u, root: false) }
      }
    end

  end

  Presence::Engine.routes.draw do
    post '/publish' => 'presences#publish'
  end

  Discourse::Application.routes.append do
    mount ::Presence::Engine, at: '/presence'
  end

end
