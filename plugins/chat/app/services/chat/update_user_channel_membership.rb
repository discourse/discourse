# frozen_string_literal: true

module Chat
  # Service responsible for updating a user's channel membership settings.
  # Currently supports updating the pinned status of a channel.
  #
  # @example
  #  ::Chat::UpdateUserChannelMembership.call(
  #    guardian: guardian,
  #    params: {
  #      channel_id: 1,
  #      pinned: true
  #    }
  #  )
  #
  class UpdateUserChannelMembership
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param guardian [Guardian]
    #   @param params [Hash]
    #   @option params [Integer] :channel_id
    #   @option params [Boolean] :pinned

    params do
      attribute :channel_id, :integer
      attribute :pinned, :boolean

      validates :channel_id, presence: true
      validates :pinned, inclusion: { in: [true, false] }
    end

    model :channel
    model :membership
    policy :can_access_channel
    transaction { step :update_membership }

    private

    def fetch_channel(params:)
      Chat::Channel.find_by(id: params.channel_id)
    end

    def fetch_membership(channel:, guardian:)
      Chat::ChannelMembershipManager.new(channel).find_for_user(guardian.user)
    end

    def can_access_channel(guardian:, membership:)
      guardian.can_preview_chat_channel?(membership.chat_channel)
    end

    def update_membership(membership:, params:)
      membership.update!(pinned: params.pinned)
      context[:membership] = membership
    end
  end
end
