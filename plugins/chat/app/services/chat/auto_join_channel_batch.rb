# NOTE: When changing auto-join logic, make sure to update the `settings.auto_join_users_info` translation as well.
# frozen_string_literal: true

module Chat
  # Service responsible to create memberships for a channel and a section of user ids
  #
  # @example
  #  Chat::AutoJoinChannelBatch.call(
  #    params: {
  #      channel_id: 1,
  #      start_user_id: 27,
  #      end_user_id: 58,
  #    }
  #  )
  #
  class AutoJoinChannelBatch
    include Service::Base

    contract do
      # Backward-compatible attributes
      attribute :chat_channel_id, :integer
      attribute :starts_at, :integer
      attribute :ends_at, :integer

      # New attributes
      attribute :channel_id, :integer
      attribute :start_user_id, :integer
      attribute :end_user_id, :integer

      validates :channel_id, :start_user_id, :end_user_id, presence: true
      validates :end_user_id, comparison: { greater_than_or_equal_to: :start_user_id }

      # TODO (joffrey): remove after migration is done
      before_validation do
        self.channel_id ||= chat_channel_id
        self.start_user_id ||= starts_at
        self.end_user_id ||= ends_at
      end
    end
    model :channel
    step :create_memberships
    step :recalculate_user_count
    step :publish_new_channel

    private

    def fetch_channel(contract:)
      ::Chat::CategoryChannel.find_by(id: contract.channel_id, auto_join_users: true)
    end

    def create_memberships(channel:, contract:)
      context[:added_user_ids] = ::Chat::Action::CreateMembershipsForAutoJoin.call(
        channel: channel,
        contract: contract,
      )
    end

    def recalculate_user_count(channel:, added_user_ids:)
      # Only do this if we are running auto-join for a single user, if we
      # are doing it for many then we should do it after all batches are
      # complete for the channel in Jobs::AutoJoinChannelMemberships
      return unless added_user_ids.one?
      ::Chat::ChannelMembershipManager.new(channel).recalculate_user_count
    end

    def publish_new_channel(channel:, added_user_ids:)
      ::Chat::Publisher.publish_new_channel(channel, User.where(id: added_user_ids))
    end
  end
end
