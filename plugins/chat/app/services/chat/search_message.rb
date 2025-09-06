# frozen_string_literal: true

module Chat
  # Service responsible to search messages in channels.
  #
  # @example
  #  ::Chat::SearchMessage.call(
  #    guardian: guardian,
  #    params: {
  #      term: "foo",
  #      channel_id: 1,
  #    }
  #  )
  #
  class SearchMessage
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [String] :term The term used to query the results
    #   @option params [Integer] :channel_id ID of the channel to scope the search
    #   @return [Service::Base::Context]

    def self.advanced_filter(trigger, &block)
      advanced_filters[trigger] = block
    end

    def self.advanced_filters
      @advanced_filters ||= {}
    end

    advanced_filter(/\A\@(\S+)\z/i) do |messages, match|
      username = User.normalize_username(match)
      user_id = User.not_staged.where(username_lower: username).pick(:id)
      user_id = @guardian.user&.id if !user_id && username == "me"

      if user_id
        messages.where(user_id: user_id)
      else
        messages.where("1 = 0")
      end
    end

    params do
      attribute :term, :string, default: ""
      attribute :channel_id, :integer
      attribute :limit, :integer, default: 20

      validates :channel_id, presence: true
      validates :limit, numericality: { in: 1..40 }
    end

    model :channel
    policy :can_view_channel
    model :messages, optional: true

    private

    def fetch_channel(params:)
      ::Chat::Channel.find_by(id: params.channel_id)
    end

    def can_view_channel(guardian:, channel:)
      guardian.can_preview_chat_channel?(channel)
    end

    def fetch_messages(params:, guardian:, channel:)
      return ::Chat::Message.none if params.term.blank?

      @guardian = guardian
      cleaned_term = Search.clean_term(params.term)
      processed_term = process_advanced_search!(cleaned_term)

      messages = ::Chat::Message.joins(:chat_channel).where("chat_channels.id IN (?)", channel.id)
      messages = apply_filters(messages)

      if processed_term.present?
        prepared_term = Search.prepare_data(processed_term)
        ts_config = Search.ts_config
        ts_query = Search.ts_query(term: prepared_term, ts_config: ts_config)
        messages =
          messages.joins(:message_search_data).where(
            "chat_message_search_data.search_data @@ #{ts_query}",
          )
      elsif @filters.blank?
        return ::Chat::Message.none
      end

      messages.order(created_at: :desc).limit(params.limit)
    end

    private

    def process_advanced_search!(term)
      term
        .to_s
        .split(/\s+/)
        .map do |word|
          next if word.blank?

          found = false

          self.class.advanced_filters.each do |matcher, block|
            if word =~ matcher
              (@filters ||= []) << [block, $1]
              found = true
              break
            end
          end

          found ? nil : word
        end
        .compact
        .join(" ")
    end

    def apply_filters(messages)
      @filters&.each do |block, match|
        if block.arity == 1
          messages = instance_exec(messages, &block) || messages
        else
          messages = instance_exec(messages, match, &block) || messages
        end
      end

      messages
    end
  end
end
