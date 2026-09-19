# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module ChatChannelSelection
        MAX_LOAD_OPTIONS = 200
        CHANNEL_NAME_SQL = "COALESCE(chat_channels.name, categories.name)"

        def self.selectable_channels
          ::Chat::Channel.public_channels.where(status: ::Chat::Channel.statuses[:open])
        end

        def self.load_options(context)
          channels = selectable_channels

          if context.filter.present?
            channels =
              channels.where(
                "LOWER(#{CHANNEL_NAME_SQL}) LIKE ?",
                "%#{ActiveRecord::Base.sanitize_sql_like(context.filter.downcase)}%",
              )
          end

          channels
            .order("LOWER(#{CHANNEL_NAME_SQL}) ASC")
            .limit(MAX_LOAD_OPTIONS)
            .pluck(:id, :name, "categories.name")
            .map do |id, channel_name, category_name|
              { id:, name: channel_name.presence || category_name }
            end
        end

        def selectable_chat_channel(channel_id)
          ChatChannelSelection.selectable_channels.find_by(id: channel_id)
        end
      end
    end
  end
end
