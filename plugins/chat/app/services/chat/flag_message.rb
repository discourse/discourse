# frozen_string_literal: true

module Chat
  # Service responsible to flag a message.
  #
  # @example
  #  ::Chat::FlagMessage.call(
  #    guardian: guardian,
  #    params: {
  #      channel_id: 1,
  #      message_id: 43,
  #    }
  #  )
  #
  class FlagMessage
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :channel_id of the channel
    #   @option params [Integer] :message_id of the message
    #   @option params [Integer] :flag_type_id Type of flag to create
    #   @option params [String] :message (optional) Used when the flag type is notify_user or notify_moderators and we have to create a separate PM.
    #   @option params [Boolean] :is_warning (optional) Staff can send warnings when using the notify_user flag.
    #   @option params [Boolean] :take_action (optional) Automatically approves the created reviewable and deletes the chat message.
    #   @option params [Boolean] :queue_for_review (optional) Adds a special reason to the reviewable score and creates the reviewable using the force_review option.
    #   @return [Service::Base::Context]

    params do
      attribute :message_id, :integer
      attribute :channel_id, :integer
      attribute :flag_type_id, :integer
      attribute :message, :string
      attribute :is_warning, :boolean
      attribute :take_action, :boolean
      attribute :queue_for_review, :boolean

      validates :message_id, presence: true
      validates :channel_id, presence: true
      validates :flag_type_id, inclusion: { in: -> { ::ReviewableScore.types.values } }
    end
    model :message
    policy :can_flag_message_in_channel
    step :flag_message

    private

    def fetch_message(params:)
      Chat::Message.includes(:chat_channel, :revisions).find_by(
        id: params[:message_id],
        chat_channel_id: params[:channel_id],
      )
    end

    def can_flag_message_in_channel(guardian:, params:, message:)
      guardian.can_join_chat_channel?(message.chat_channel) &&
        guardian.can_flag_chat_message?(message) &&
        guardian.can_flag_message_as?(
          message,
          params[:flag_type_id],
          params.slice(:queue_for_review, :take_action, :is_warning),
        )
    end

    def flag_message(message:, params:, guardian:)
      Chat::ReviewQueue.new.flag_message(
        message,
        guardian,
        params[:flag_type_id],
        **params.slice(:message, :is_warning, :take_action, :queue_for_review),
      )
    end
  end
end
