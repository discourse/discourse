# frozen_string_literal: true

module Chat
  module Action
    module SearchMessage
      # Processes a search query to extract advanced filters, apply them to messages,
      # and return cleaned query text.
      #
      # Parses query strings to identify special filter syntax:
      # - @username filters (e.g., "@alice" or "@me")
      # - #channel filters (e.g., "#general")
      #
      # Then applies those filters to the provided messages relation.
      #
      # Returns a result object containing:
      # - processed_query: The query text with filter terms removed
      # - filters: Array of [filter_type, match] tuples
      # - messages: The filtered messages ActiveRecord::Relation
      class ProcessSearchQuery < Service::ActionBase
        # @param [String] query The search query to process
        # @param [ActiveRecord::Relation] messages The messages relation to filter
        # @param [Guardian] guardian The current user's guardian for permission checks
        option :query
        option :messages
        option :guardian

        Result = Struct.new(:processed_query, :filters, :messages)

        MAX_FILTERS = 10

        def call
          set_filters_and_query_words
          Result.new(processed_query, filters, filtered_messages)
        end

        private

        def filters
          @filters ||= []
        end

        def query_words
          @query_words ||= []
        end

        def usernames
          @usernames ||= filters.select { |type, _| type == :username }.map(&:last)
        end

        def channel_slugs
          @channel_slugs ||= filters.select { |type, _| type == :channel }.map(&:last)
        end

        def set_filters_and_query_words
          query
            .to_s
            .split(/\s+/)
            .each do |word|
              next if word.blank?

              # Check for @username filter
              if word =~ /\A\@(\S+)\z/i
                filters << [:username, $1]
                # Check for #channel filter
              elsif word =~ /\A\#(\S+)\z/i
                filters << [:channel, $1]
              else
                query_words << word
              end
            end

          @filters = filters.first(MAX_FILTERS)
        end

        def processed_query
          @processed_query ||= query_words.join(" ")
        end

        def user_id_lookup
          @user_id_lookup ||=
            begin
              return {} if usernames.empty?

              normalized_usernames = usernames.map(&User.method(:normalize_username))
              me_index = normalized_usernames.index("me")
              normalized_usernames[me_index] = guardian.user&.username_lower if me_index

              User
                .not_staged
                .where(username_lower: normalized_usernames.compact)
                .pluck(:username_lower, :id)
                .to_h
            end
        end

        def channel_lookup
          @channel_lookup ||=
            begin
              return {} if channel_slugs.empty?

              Chat::Channel.where(slug: channel_slugs.map(&:downcase)).index_by(&:slug)
            end
        end

        def filtered_messages
          messages
            .then { apply_username_filters(_1) }
            .then { apply_channel_filters(_1) }
            .then { apply_ts_query(_1) }
        end

        def apply_ts_query(messages)
          return messages if processed_query.blank?
          ts_query =
            Search.ts_query(term: Search.prepare_data(processed_query), ts_config: Search.ts_config)
          messages.joins(:message_search_data).where(
            "chat_message_search_data.search_data @@ #{ts_query}",
          )
        end

        def apply_username_filters(messages)
          usernames.reduce(messages) do |filtered, username|
            normalized_username = User.normalize_username(username)
            normalized_username = guardian.user&.username_lower if normalized_username == "me"

            user_id = user_id_lookup[normalized_username]
            user_id ? filtered.where(user_id:) : filtered.where("1 = 0")
          end
        end

        def apply_channel_filters(messages)
          channel_slugs.reduce(messages) do |filtered, slug|
            channel = channel_lookup[slug.downcase]

            if channel.present? && guardian.can_preview_chat_channel?(channel)
              filtered.where("chat_channels.id = ?", channel.id)
            else
              filtered.where("1 = 0")
            end
          end
        end
      end
    end
  end
end
