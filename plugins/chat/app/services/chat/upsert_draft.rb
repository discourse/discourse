# frozen_string_literal: true

module Chat
  # Service responsible to create draft for a channel, or a channel’s thread.
  #
  # @example
  #  ::Chat::UpsertDraft.call(
  #    guardian: guardian,
  #    channel_id: 1,
  #    thread_id: 1,
  #    data: { message: "foo" }
  #  )
  #
  class UpsertDraft
    include Service::Base

    # @!method call(guardian:, channel_id:, thread_id:, data:)
    #   @param [Guardian] guardian
    #   @param [Integer] channel_id of the channel
    #   @param [String] json object as string containing the data of the draft (message, uploads, replyToMsg and editing keys)
    #   @option [Integer] thread_id of the channel
    #   @return [Service::Base::Context]
    contract
    model :channel
    policy :can_upsert_draft
    step :check_thread_exists
    step :upsert_draft

    # @!visibility private
    class Contract
      attribute :channel_id, :integer
      validates :channel_id, presence: true

      attribute :thread_id, :integer
      attribute :data, :string
    end

    private

    def fetch_channel(contract:)
      Chat::Channel.find_by(id: contract.channel_id)
    end

    def can_upsert_draft(guardian:, channel:)
      guardian.can_chat? && guardian.can_join_chat_channel?(channel)
    end

    def check_thread_exists(contract:, channel:)
      if contract.thread_id.present?
        fail!("Thread not found") if !channel.threads.exists?(id: contract.thread_id)
      end
    end

    def upsert_draft(contract:, guardian:)
      if contract.data.present?
        draft =
          Chat::Draft.find_or_initialize_by(
            user_id: guardian.user.id,
            chat_channel_id: contract.channel_id,
            thread_id: contract.thread_id,
          )
        draft.data = contract.data
        draft.save!
      else
        # when data is empty, we destroy the draft
        Chat::Draft.where(
          user: guardian.user,
          chat_channel_id: contract.channel_id,
          thread_id: contract.thread_id,
        ).destroy_all
      end
    end
  end
end
