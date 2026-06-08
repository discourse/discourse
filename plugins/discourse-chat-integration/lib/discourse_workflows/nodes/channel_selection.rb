# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module ChatIntegrationChannelSelection
        MAX_LOAD_OPTIONS = 200

        def self.channel_label(channel)
          provider = DiscourseChatIntegration::Provider.get_by_name(channel.provider)

          identifier =
            if provider&.const_defined?(:CHANNEL_IDENTIFIER_KEY)
              channel.data[provider::CHANNEL_IDENTIFIER_KEY]
            else
              channel.data.values.first
            end

          # In the Node UI it looks like this:
          # "Slack: #general" or "Discord: updates"
          "#{channel.provider}: #{identifier}"
        end

        def self.load_options(context)
          options =
            DiscourseChatIntegration::Channel.all.map do |channel|
              { id: channel.id, name: channel_label(channel) }
            end

          if context.filter.present?
            filter = context.filter.downcase
            options = options.select { |option| option[:name].downcase.include?(filter) }
          end

          options.sort_by { |option| option[:name].downcase }.first(MAX_LOAD_OPTIONS)
        end

        def selectable_channel(channel_id)
          DiscourseChatIntegration::Channel.find_by(id: channel_id)
        end
      end
    end
  end
end
