# frozen_string_literal: true

class Chat::ChatMessageReactor
  ADD_REACTION = :add
  REMOVE_REACTION = :remove
  MAX_REACTIONS_LIMIT = 30

  def initialize(user, chat_channel)
    @user = user
    @chat_channel = chat_channel
    @guardian = Guardian.new(user)
  end

  def react!(message_id:, react_action:, emoji:)
    @guardian.ensure_can_join_chat_channel!(@chat_channel)
    @guardian.ensure_can_react!
    validate_channel_status!
    validate_reaction!(react_action, emoji)
    message = ensure_chat_message!(message_id)
    validate_max_reactions!(message, react_action, emoji)

    reaction = nil
    ActiveRecord::Base.transaction do
      enforce_channel_membership!
      reaction = create_reaction(message, react_action, emoji)
    end

    publish_reaction(message, react_action, emoji)

    reaction
  end

  private

  def ensure_chat_message!(message_id)
    message = ChatMessage.find_by(id: message_id, chat_channel: @chat_channel)
    raise Discourse::NotFound unless message
    message
  end

  def validate_reaction!(react_action, emoji)
    if ![ADD_REACTION, REMOVE_REACTION].include?(react_action) || !Emoji.exists?(emoji)
      raise Discourse::InvalidParameters
    end
  end

  def enforce_channel_membership!
    Chat::ChatChannelMembershipManager.new(@chat_channel).follow(@user)
  end

  def validate_channel_status!
    return if @guardian.can_create_channel_message?(@chat_channel)
    raise Discourse::InvalidAccess.new(
            nil,
            nil,
            custom_message: "chat.errors.channel_modify_message_disallowed.#{@chat_channel.status}",
          )
  end

  def validate_max_reactions!(message, react_action, emoji)
    if react_action == ADD_REACTION &&
         message.reactions.count("DISTINCT emoji") >= MAX_REACTIONS_LIMIT &&
         !message.reactions.exists?(emoji: emoji)
      raise Discourse::InvalidAccess.new(
              nil,
              nil,
              custom_message: "chat.errors.max_reactions_limit_reached",
            )
    end
  end

  def create_reaction(message, react_action, emoji)
    if react_action == ADD_REACTION
      message.reactions.find_or_create_by!(user: @user, emoji: emoji)
    else
      message.reactions.where(user: @user, emoji: emoji).destroy_all
    end
  end

  def publish_reaction(message, react_action, emoji)
    ChatPublisher.publish_reaction!(@chat_channel, message, react_action, @user, emoji)
  end
end
