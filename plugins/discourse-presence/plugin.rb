# name: discourse-presence
# about: Show which users are writing a reply to a topic
# version: 1.0
# authors: André Pereira, David Taylor
# url: https://github.com/discourse/discourse-presence.git

enabled_site_setting :presence_enabled

register_asset 'stylesheets/presence.scss'

PLUGIN_NAME ||= "discourse-presence".freeze

after_initialize do

  module ::Presence
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace Presence
    end
  end

  module ::Presence::PresenceManager
    def self.get_redis_key(type, id)
      "presence:#{type}:#{id}"
    end

    def self.get_messagebus_channel(type, id)
      "/presence/#{type}/#{id}"
    end

    def self.add(type, id, user_id)
      redis_key = get_redis_key(type, id)
      response = $redis.hset(redis_key, user_id, Time.zone.now)

      response # Will be true if a new key
    end

    def self.remove(type, id, user_id)
      redis_key = get_redis_key(type, id)
      response = $redis.hdel(redis_key, user_id)

      response > 0 # Return true if key was actually deleted
    end

    def self.get_users(type, id)
      redis_key = get_redis_key(type, id)
      user_ids = $redis.hkeys(redis_key).map(&:to_i)

      User.where(id: user_ids)
    end

    def self.publish(type, id)
      users = get_users(type, id)
      serialized_users = users.map { |u| BasicUserSerializer.new(u, root: false) }
      message = {
        users: serialized_users
      }
      MessageBus.publish(get_messagebus_channel(type, id), message.as_json)

      users
    end

    def self.cleanup(type, id)
      hash = $redis.hgetall(get_redis_key(type, id))
      original_hash_size = hash.length

      any_changes = false

      # Delete entries older than 20 seconds
      hash.each do |user_id, time|
        if Time.zone.now - Time.parse(time) >= 20
          any_changes ||= remove(type, id, user_id)
        end
      end

      any_changes
    end

  end

  require_dependency "application_controller"

  class Presence::PresencesController < ::ApplicationController
    before_filter :ensure_logged_in

    def publish
      data = params.permit(:response_needed,
              current: [:compose_state, :action, :topic_id, :post_id],
              previous: [:compose_state, :action, :topic_id, :post_id]
              )

      if data[:previous] &&
          data[:previous][:compose_state] == 'open' &&
          data[:previous][:action].in?(['edit', 'reply'])

        type = data[:previous][:post_id] ? 'post' : 'topic'
        id = data[:previous][:post_id] ? data[:previous][:post_id] : data[:previous][:topic_id]

        any_changes = false
        any_changes ||= Presence::PresenceManager.remove(type, id, current_user.id)
        any_changes ||= Presence::PresenceManager.cleanup(type, id)

        users = Presence::PresenceManager.publish(type, id) if any_changes
      end

      if data[:current] &&
          data[:current][:compose_state] == 'open' &&
          data[:current][:action].in?(['edit', 'reply'])

        type = data[:current][:post_id] ? 'post' : 'topic'
        id = data[:current][:post_id] ? data[:current][:post_id] : data[:current][:topic_id]

        any_changes = false
        any_changes ||= Presence::PresenceManager.add(type, id, current_user.id)
        any_changes ||= Presence::PresenceManager.cleanup(type, id)

        users = Presence::PresenceManager.publish(type, id) if any_changes

        if data[:response_needed]
          users ||= Presence::PresenceManager.get_users(type, id)

          serialized_users = users.map { |u| BasicUserSerializer.new(u, root: false) }

          messagebus_channel = Presence::PresenceManager.get_messagebus_channel(type, id)

          render json: {
            messagebus_channel: messagebus_channel,
            messagebus_id: MessageBus.last_id(messagebus_channel),
            users: serialized_users
          }
          return
        end
      end

      render json: {}
    end

  end

  Presence::Engine.routes.draw do
    post '/publish' => 'presences#publish'
  end

  Discourse::Application.routes.append do
    mount ::Presence::Engine, at: '/presence'
  end

end
