# frozen_string_literal: true

module Chat
  # Service responsible to flag a message.
  #
  # @example
  #  ::Chat::FlagMessage.call(
  #    guardian: guardian,
  #    channel_id: 1,
  #    message_id: 43,
  #  )
  #
  class FlagMessage
    include Service::Base

    # @!method call(guardian:, channel_id:, data:)
    #   @param [Guardian] guardian
    #   @param [Integer] channel_id of the channel
    #   @param [Integer] message_id of the message
    #   @param [Integer] flag_type_id - Type of flag to create
    #   @param [String] optional message - Used when the flag type is notify_user or notify_moderators and we have to create
    #     a separate PM.
    #   @param [Boolean] optional is_warning - Staff can send warnings when using the notify_user flag.
    #   @param [Boolean] optional take_action - Automatically approves the created reviewable and deletes the chat message.
    #   @param [Boolean] optional queue_for_review - Adds a special reason to the reviewable score and creates the reviewable using
    #     the force_review option.

    #   @return [Service::Base::Context]
    contract do
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

    def fetch_message(contract:)
      Chat::Message.includes(:chat_channel, :revisions).find_by(
        id: contract.message_id,
        chat_channel_id: contract.channel_id,
      )
    end

    def can_flag_message_in_channel(guardian:, contract:, message:)
      guardian.can_join_chat_channel?(message.chat_channel) &&
        guardian.can_flag_chat_message?(message) &&
        guardian.can_flag_message_as?(
          message,
          contract.flag_type_id,
          {
            queue_for_review: contract.queue_for_review,
            take_action: contract.take_action,
            is_warning: contract.is_warning,
          },
        )
    end

    def flag_message(message:, contract:, guardian:)
      Chat::ReviewQueue.new.flag_message(
        message,
        guardian,
        contract.flag_type_id,
        message: contract.message,
        is_warning: contract.is_warning,
        take_action: contract.take_action,
        queue_for_review: contract.queue_for_review,
      )
    end
  end
end
