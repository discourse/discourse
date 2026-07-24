# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    module Tools
      class SearchChatChannels < Base
        MAX_RESULTS = 20
        CHANNEL_NAME_SQL = "COALESCE(chat_channels.name, categories.name)"

        def self.signature
          {
            name: name,
            description:
              "Searches open Discourse chat channels and returns channel names and IDs for workflow chat node parameters.",
            parameters: [
              {
                name: "query",
                description:
                  "Partial channel name, slug, category name, or #channel mention to search for",
                type: "string",
                required: false,
              },
            ],
          }
        end

        def self.name
          "search_chat_channels"
        end

        def self.available?
          defined?(::Chat::Channel) && defined?(SiteSetting.chat_enabled) &&
            SiteSetting.chat_enabled
        end

        def invoke
          return not_allowed_response if !ensure_can_manage_workflows!
          return error_response("Chat is not enabled") if !self.class.available?

          query = normalize_query(parameters[:query])

          {
            status: "success",
            query: query,
            matches: channels_matching(query).map { |channel| channel_data(channel) },
          }
        end

        private

        def channels_matching(query)
          channels =
            ::Chat::Channel
              .public_channels
              .includes(:chatable)
              .where(status: ::Chat::Channel.statuses[:open])

          if query.present?
            sql_query = "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%"
            channels =
              channels.where(
                "LOWER(#{CHANNEL_NAME_SQL}) LIKE :query OR LOWER(chat_channels.slug) LIKE :query OR LOWER(categories.slug) LIKE :query",
                query: sql_query,
              )
          end

          channels.order("LOWER(#{CHANNEL_NAME_SQL}) ASC").limit(MAX_RESULTS)
        end

        def channel_data(channel)
          category = channel.chatable if channel.chatable.is_a?(::Category)

          {
            id: channel.id,
            name: channel.name.presence || category&.name,
            slug: channel.slug,
            category_id: category&.id,
            category_name: category&.name,
            category_slug: category&.slug,
            url: channel.relative_url,
          }
        end

        def normalize_query(query)
          query.to_s.strip.delete_prefix("#").strip
        end
      end
    end
  end
end
