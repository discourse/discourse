# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    module Tools
      class SearchChatIntegrationChannels < Base
        MAX_RESULTS = 20

        class << self
          def signature
            {
              name: name,
              description:
                "Searches configured external chat integration channels and returns provider names, channel labels, and IDs for workflow parameters.",
              parameters: [
                {
                  name: "query",
                  description: "Partial provider or channel name to search for",
                  type: "string",
                  required: false,
                },
              ],
            }
          end

          def name
            "search_chat_integration_channels"
          end

          def available?
            defined?(DiscourseWorkflows::Nodes::ChatIntegrationChannelSelection) &&
              defined?(SiteSetting.chat_integration_enabled) && SiteSetting.chat_integration_enabled
          end
        end

        def invoke
          return not_allowed_response if !ensure_can_manage_workflows!
          return error_response("Chat integration is not enabled") if !self.class.available?

          query = normalize_query(parameters[:query])

          { status: "success", query: query, matches: channels_matching(query) }
        end

        private

        def channels_matching(query)
          selection = DiscourseWorkflows::Nodes::ChatIntegrationChannelSelection
          matches =
            selection.selectable_channels.map do |channel|
              { id: channel.id, name: selection.channel_label(channel), provider: channel.provider }
            end

          if query.present?
            matches.select! do |match|
              [match[:name], match[:provider]].any? { |value| value.downcase.include?(query) }
            end
          end

          matches.sort_by { |match| match[:name].downcase }.first(MAX_RESULTS)
        end

        def normalize_query(query)
          query.to_s.strip.delete_prefix("#").strip.downcase
        end
      end
    end
  end
end
