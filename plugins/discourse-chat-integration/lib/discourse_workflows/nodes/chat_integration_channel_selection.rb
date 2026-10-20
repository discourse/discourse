# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module ChatIntegrationChannelSelection
        MAX_LOAD_OPTIONS = 200

        def self.channel_label(channel)
          provider = DiscourseChatIntegration::Provider.get_by_name(channel.provider)

          "#{channel.provider}: #{channel_identifier(channel, provider)}"
        end

        def self.channel_identifier(channel, provider = nil)
          provider ||= DiscourseChatIntegration::Provider.get_by_name(channel.provider)

          if provider&.const_defined?(:CHANNEL_IDENTIFIER_KEY)
            channel.data[provider::CHANNEL_IDENTIFIER_KEY]
          else
            channel.data.values.first
          end
        end

        def self.selectable_channels
          provider_names = DiscourseChatIntegration::Provider.enabled_provider_names
          return DiscourseChatIntegration::Channel.none if provider_names.empty?

          DiscourseChatIntegration::Channel.where("value::json->>'provider' IN (?)", provider_names)
        end

        def self.load_options(context)
          options =
            selectable_channels.map { |channel| { id: channel.id, name: channel_label(channel) } }

          options.select! { |option| context.matches_filter?(option[:name]) }

          options.sort_by { |option| option[:name].downcase }.first(MAX_LOAD_OPTIONS)
        end

        def selectable_channel(channel_id)
          DiscourseChatIntegration::Channel.find_by(id: channel_id)
        end
      end
    end
  end
end
