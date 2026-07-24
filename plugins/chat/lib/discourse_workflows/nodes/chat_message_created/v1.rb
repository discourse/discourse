# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module ChatMessageCreated
        class V1 < NodeType
          include ChatChannelSelection

          description(
            name: "trigger:chat_message_created",
            version: "1.0",
            defaults: {
              icon: "comments",
              color: "teal",
            },
            group: "discourse_triggers",
            available: -> { SiteSetting.chat_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_chat",
            output_contracts: [
              {
                schema: {
                  "$schema" => DiscourseWorkflows::Schema::DRAFT_URI,
                  "type" => "object",
                  "properties" => {
                    "message" => {
                      "type" => "object",
                      "properties" => {
                        "id" => {
                          "type" => "integer",
                        },
                        "message" => {
                          "type" => "string",
                        },
                        "cooked" => {
                          "type" => "string",
                        },
                        "excerpt" => {
                          "type" => "string",
                        },
                        "created_at" => {
                          "type" => "string",
                          "format" => "date-time",
                        },
                        "thread_id" => {
                          "type" => %w[integer null],
                        },
                        "chat_channel_id" => {
                          "type" => "integer",
                        },
                      },
                    },
                    "channel" => {
                      "type" => "object",
                      "properties" => {
                        "id" => {
                          "type" => "integer",
                        },
                        "title" => {
                          "type" => "string",
                        },
                        "slug" => {
                          "type" => "string",
                        },
                        "chatable_type" => {
                          "type" => "string",
                        },
                        "chatable_id" => {
                          "type" => "integer",
                        },
                      },
                    },
                    "user" => {
                      "type" => "object",
                      "properties" => DiscourseWorkflows::Schema::BASIC_USER_PROPERTIES,
                    },
                  },
                },
              },
            ],
            properties: {
              channel_id: {
                type: :integer,
                required: false,
                type_options: {
                  load_options_method: "chat_channels",
                },
                no_data_expression: true,
                ui: {
                  control: :combo_box,
                },
                control_options: {
                  filterable: true,
                  value_property: :id,
                  name_property: :name,
                  set_from_option: {
                    channel_name: "name",
                  },
                },
              },
              channel_name: {
                type: :string,
                ui: {
                  hidden: true,
                },
              },
            },
          )

          def initialize(message, channel, user)
            super(parameters: {})
            @message = message
            @channel = channel
            @user = user
          end

          def self.load_options_context(context)
            case context.method_name
            when "chat_channels"
              ChatChannelSelection.load_options(context)
            end
          end

          def valid?
            @message.present? && @channel.present?
          end

          def matches?(trigger_ctx)
            return false if selectable_chat_channel(@channel.id).blank?

            channel_id = trigger_ctx.get_node_parameter("channel_id").presence
            channel_id.blank? || channel_id.to_i == @channel.id
          end

          def output
            {
              message: {
                id: @message.id,
                message: @message.message,
                cooked: @message.cooked,
                excerpt: @message.excerpt || @message.build_excerpt,
                created_at: @message.created_at.iso8601,
                thread_id: @message.thread_id,
                chat_channel_id: @message.chat_channel_id,
              },
              channel: {
                id: @channel.id,
                title: @channel.title(@user),
                slug: @channel.slug,
                chatable_type: @channel.chatable_type,
                chatable_id: @channel.chatable_id,
              },
              user: user_data,
            }
          end

          private

          def user_data
            return {} if @user.blank?

            serialize_record(@user, BasicUserSerializer)
          end
        end
      end
    end
  end
end
