# frozen_string_literal: true

module Chat
  # Service responsible to create draft for a channel, or a channel’s thread.
  #
  # @example
  #  ::Chat::UpsertDraft.call(
  #    guardian: guardian,
  #    params: {
  #      channel_id: 1,
  #      thread_id: 1,
  #      data: { message: "foo" }
  #    }
  #  )
  #
  class UpsertDraft
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :channel_id ID of the channel
    #   @option params [String] :data JSON object as string containing the data of the draft (message, uploads, replyToMsg and editing keys)
    #   @option params [Integer] :thread_id ID of the thread
    #   @return [Service::Base::Context]

    params do
      attribute :channel_id, :integer
      attribute :thread_id, :integer
      attribute :data, :string

      validates :channel_id, presence: true
    end
    model :channel
    policy :can_upsert_draft
    step :check_thread_exists
    step :upsert_draft

    private

    def fetch_channel(params:)
      Chat::Channel.find_by(id: params[:channel_id])
    end

    def can_upsert_draft(guardian:, channel:)
      guardian.can_chat? && guardian.can_join_chat_channel?(channel)
    end

    def check_thread_exists(params:, channel:)
      return if params[:thread_id].blank?
      fail!("Thread not found") if !channel.threads.exists?(id: params[:thread_id])
    end

    def upsert_draft(params:, guardian:)
      if params[:data].present?
        draft =
          Chat::Draft.find_or_initialize_by(
            user_id: guardian.user.id,
            chat_channel_id: params[:channel_id],
            thread_id: params[:thread_id],
          )
        draft.data = params[:data]
        draft.save!
      else
        # when data is empty, we destroy the draft
        Chat::Draft.where(
          user: guardian.user,
          chat_channel_id: params[:channel_id],
          thread_id: params[:thread_id],
        ).destroy_all
      end
    end
  end
end
