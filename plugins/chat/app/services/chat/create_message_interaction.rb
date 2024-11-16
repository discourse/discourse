# frozen_string_literal: true

module Chat
  # Service responsible for creating and validating a new interaction between a user and a message.
  #
  # @example
  #  Chat::CreateMessageInteraction.call(params: { message_id: 3, action_id: "xxx" }, guardian: guardian)
  #
  class CreateMessageInteraction
    include ::Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :message_id
    #   @option params [Integer] :action_id
    #   @return [Service::Base::Context]
    params do
      attribute :message_id, :integer
      validates :message_id, presence: true

      attribute :action_id, :string
      validates :action_id, presence: true
    end

    model :message
    policy :can_interact_with_message
    model :action

    transaction do
      model :interaction
      step :trigger_interaction
    end

    private

    def fetch_message(params:)
      Chat::Message.find_by(id: params.message_id)
    end

    def fetch_action(params:, message:)
      message.blocks&.find do |item|
        item["elements"].find { |element| element["action_id"] == params.action_id }
      end
    end

    def can_interact_with_message(guardian:, message:)
      guardian.can_preview_chat_channel?(message.chat_channel)
    end

    def fetch_interaction(guardian:, message:, action:)
      Chat::MessageInteraction.create(user: guardian.user, message:, action:)
    end

    def trigger_interaction(interaction:)
      DiscourseEvent.trigger(:chat_message_interaction, interaction)
    end
  end
end
