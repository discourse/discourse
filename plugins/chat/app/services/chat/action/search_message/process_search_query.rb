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

        def call
          filters = []
          filtered_messages = messages

          processed_query =
            query
              .to_s
              .split(/\s+/)
              .map do |word|
                next if word.blank?

                found = false

                # Check for @username filter
                if word =~ /\A\@(\S+)\z/i
                  filters << [:username, $1]
                  filtered_messages =
                    Chat::Action::SearchMessage::ApplyUsernameFilter.call(
                      messages: filtered_messages,
                      match: $1,
                      guardian:,
                    )
                  found = true
                  # Check for #channel filter
                elsif word =~ /\A\#(\S+)\z/i
                  filters << [:channel, $1]
                  filtered_messages =
                    Chat::Action::SearchMessage::ApplyChannelFilter.call(
                      messages: filtered_messages,
                      match: $1,
                      guardian:,
                    )
                  found = true
                end

                found ? nil : word
              end
              .compact
              .join(" ")

          Result.new(processed_query, filters, filtered_messages)
        end
      end
    end
  end
end
