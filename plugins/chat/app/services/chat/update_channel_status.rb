# frozen_string_literal: true

module Chat
  # Service responsible for updating a chat channel status.
  #
  # @example
  #  Chat::UpdateChannelStatus.call(guardian: guardian, params: { status: "open", channel_id: 2 })
  #
  class UpdateChannelStatus
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :channel_id
    #   @option params [String] :status
    #   @return [Service::Base::Context]

    model :channel, :fetch_channel
    contract do
      attribute :status, :string

      validates :status, inclusion: { in: Chat::Channel.editable_statuses.keys }
    end
    policy :check_channel_permission
    step :change_status

    private

    def fetch_channel(params:)
      Chat::Channel.find_by(id: params[:channel_id])
    end

    def check_channel_permission(guardian:, channel:, contract:)
      guardian.can_preview_chat_channel?(channel) &&
        guardian.can_change_channel_status?(channel, contract.status.to_sym)
    end

    def change_status(channel:, contract:, guardian:)
      channel.public_send("#{contract.status}!", guardian.user)
    end
  end
end
