# frozen_string_literal: true

# GroupMessage sends a private message to a group.
# It will also avoid sending the same message repeatedly, which can happen with
# notifications to moderators when spam is detected.
#
# Options:
#
#   user: (User) If the message is about a user, pass the user object.
#   limit_once_per: (seconds) Limit sending the given type of message once every X seconds.
#                   The default is 24 hours. Set to false to always send the message.

class GroupMessage

  include Rails.application.routes.url_helpers

  RECENT_MESSAGE_PERIOD = 3.months

  def self.create(group_name, message_type, opts = {})
    GroupMessage.new(group_name, message_type, opts).create
  end

  def initialize(group_name, message_type, opts = {})
    @group_name = group_name
    @message_type = message_type
    @opts = opts
  end

  def create
    unless sent_recently?
      post = PostCreator.create(
        Discourse.system_user,
        target_group_names: [@group_name],
        archetype: Archetype.private_message,
        subtype: TopicSubtype.system_message,
        title: I18n.t("system_messages.#{@message_type}.subject_template", message_params),
        raw: I18n.t("system_messages.#{@message_type}.text_body_template", message_params)
      )
      remember_message_sent
      post
    else
      false
    end
  end

  def delete_previous!(match_raw: true)
    posts = Post
      .joins(topic: { topic_allowed_groups: :group })
      .where(topic: {
        posts_count: 1,
        user_id: Discourse.system_user,
        archetype: Archetype.private_message,
        subtype: TopicSubtype.system_message,
        title: I18n.t("system_messages.#{@message_type}.subject_template", message_params),
        topic_allowed_groups: {
          groups: { name: @group_name }
        }
      })
      .where("posts.created_at > ?", RECENT_MESSAGE_PERIOD.ago)

    if match_raw
      posts = posts.where(raw: I18n.t("system_messages.#{@message_type}.text_body_template", message_params).rstrip)
    end

    posts.find_each do |post|
      PostDestroyer.new(Discourse.system_user, post).destroy
    end
  end

  def message_params
    @message_params ||= begin
      h = { base_url: Discourse.base_url }.merge(@opts[:message_params] || {})
      if @opts[:user]
        h.merge!(username: @opts[:user].username,
                 user_url: user_path(@opts[:user].username))
      end
      h
    end
  end

  def sent_recently?
    return false if @opts[:limit_once_per] == false
    Discourse.redis.get(sent_recently_key).present?
  end

  # default is to send no more than once every 24 hours (24 * 60 * 60 = 86,400 seconds)
  def remember_message_sent
    Discourse.redis.setex(sent_recently_key, @opts[:limit_once_per].try(:to_i) || 86_400, 1) unless @opts[:limit_once_per] == false
  end

  def sent_recently_key
    "grpmsg:#{@group_name}:#{@message_type}:#{@opts[:user] ? @opts[:user].username : ''}"
  end
end
