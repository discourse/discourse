# GroupMessage sends a private message to a group.
# It will also avoid sending the same message repeatedly, which can happen with
# notifications to moderators when spam is detected.
#
# Options:
#
#   user: (User) If the message is about a user, pass the user object.
#   limit_once_per: (seconds) Limit sending the given type of message once every X seconds.
#                   The default is 24 hours. Set to false to always send the message.

require_dependency 'post_creator'
require_dependency 'topic_subtype'
require_dependency 'discourse'

class GroupMessage

  include Rails.application.routes.url_helpers

  def self.create(group_name, message_type, opts={})
    GroupMessage.new(group_name, message_type, opts).create
  end

  def initialize(group_name, message_type, opts={})
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

  def message_params
    @message_params ||= begin
      h = { base_url: Discourse.base_url }.merge(@opts[:message_params] || {})
      if @opts[:user]
        h.merge!({
          username: @opts[:user].username,
          user_url: user_path(@opts[:user].username)
        })
      end
      h
    end
  end

  def sent_recently?
    return false if @opts[:limit_once_per] == false
    $redis.get(sent_recently_key).present?
  end

  # default is to send no more than once every 24 hours (24 * 60 * 60 = 86,400 seconds)
  def remember_message_sent
    $redis.setex(sent_recently_key, @opts[:limit_once_per].try(:to_i) || 86_400, 1) unless @opts[:limit_once_per] == false
  end

  def sent_recently_key
    "grpmsg:#{@group_name}:#{@message_type}:#{@opts[:user] ? @opts[:user].username : ''}"
  end
end
