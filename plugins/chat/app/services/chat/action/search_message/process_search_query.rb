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
          processed_query =
            query
              .to_s
              .split(/\s+/)
              .map do |word|
                next if word.blank?

                found = false

                # Check for @username filter
                if word =~ /\A\@(\S+)\z/i
                  (filters ||= []) << [:username, $1]
                  found = true
                  # Check for #channel filter
                elsif word =~ /\A\#(\S+)\z/i
                  (filters ||= []) << [:channel, $1]
                  found = true
                end

                found ? nil : word
              end
              .compact
              .join(" ")

          filtered_messages = apply_filters(messages, guardian, filters)

          Result.new(processed_query, filters, filtered_messages)
        end

        private

        def apply_filters(messages, guardian, filters)
          filters&.each do |filter_type, match|
            messages =
              case filter_type
              when :username
                Chat::Action::SearchMessage::ApplyUsernameFilter.call(
                  messages: messages,
                  match: match,
                  guardian: guardian,
                )
              when :channel
                Chat::Action::SearchMessage::ApplyChannelFilter.call(
                  messages: messages,
                  match: match,
                  guardian: guardian,
                )
              else
                messages
              end
          end

          messages
        end
      end
    end
  end
end
