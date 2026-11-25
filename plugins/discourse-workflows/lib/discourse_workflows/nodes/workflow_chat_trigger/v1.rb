# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module WorkflowChatTrigger
      class V1 < NodeType
        HISTORY_LIMIT = 16

        description(
          name: ChatConversation::TRIGGER_TYPE,
          version: "1.0",
          defaults: {
            icon: "comments",
            color: "teal",
          },
          group: "discourse_triggers",
          inputs: [],
          available: -> { ChatConversation.chat_available? },
          unavailable_reason_key: "discourse_workflows.node_unavailable.chat_disabled",
          capabilities: {
            provides_current_user: true,
            launch_path: "/workflows/chat/:workflow_id/:node_id",
          },
          output_contracts: [
            {
              schema:
                Schema.document(
                  "chatInput" => {
                    "type" => "string",
                  },
                  "channel_id" => {
                    "type" => "integer",
                    "description" => "ID of the direct message channel",
                  },
                  "sessionId" => {
                    "type" => "string",
                  },
                  "history" => {
                    "type" => "array",
                    "description" => "Recent messages from this DM before the current message",
                    "items" => {
                      "type" => "object",
                      "properties" => {
                        "role" => {
                          "type" => "string",
                          "enum" => %w[user assistant],
                        },
                        "content" => {
                          "type" => "string",
                        },
                      },
                    },
                  },
                  "message" => {
                    "type" => "object",
                    "properties" => {
                      "id" => {
                        "type" => "integer",
                      },
                      "content" => {
                        "type" => "string",
                      },
                      "upload_ids" => {
                        "type" => "array",
                        "items" => {
                          "type" => "integer",
                        },
                      },
                    },
                  },
                  "user" => Schema.nullable_user("Message author"),
                  "actor" => Schema.nullable_user("Member who sent the message"),
                ),
            },
          ],
          properties: {
            url_preview: {
              type: :custom,
              required: false,
              ui: {
                control: :url_preview,
              },
            },
            chat_title: {
              type: :string,
              required: false,
              no_data_expression: true,
            },
            welcome_message: {
              type: :string,
              required: false,
              no_data_expression: true,
              ui: {
                control: :textarea,
              },
            },
            chat_bot_id: {
              type: :integer,
              default: Discourse::SYSTEM_USER_ID,
              no_data_expression: true,
              type_options: {
                load_options_method: "chat_bots",
              },
              ui: {
                control: :combo_box,
              },
              control_options: {
                filterable: true,
                value_property: :id,
                name_property: :name,
              },
            },
            group_ids: {
              type: :multi_options,
              required: false,
              default: [],
              no_data_expression: true,
              type_options: {
                load_options_method: "groups",
              },
              control_options: {
                value_property: "id",
                name_property: "name",
                filterable: true,
              },
            },
          },
        )

        def self.load_options_context(context)
          choices =
            case context.method_name
            when "chat_bots"
              ChatConversation.bots.order(:username).pluck(:id, :username)
            when "groups"
              ::Group.order(:name).pluck(:id, :name)
            else
              return
            end

          choices.filter_map { |id, name| { id:, name: } if context.matches_filter?(name) }
        end

        def initialize(message, conversation)
          super(parameters: {})
          @message = message
          @conversation = conversation
        end

        def output
          actor = serialize_user(@message.user, guardian: @message.user.guardian)
          text = @message.message.to_s
          {
            "chatInput" => text,
            "channel_id" => @message.chat_channel_id,
            "sessionId" => @message.chat_channel_id.to_s,
            "message" => {
              "id" => @message.id,
              "content" => text,
              "upload_ids" => @message.upload_ids,
            },
            "history" => history,
            "user" => actor,
            "actor" => actor,
          }
        end

        private

        def history
          @message
            .chat_channel
            .chat_messages
            .where(id: ...@message.id, user_id: [@conversation.user_id, @conversation.bot_user_id])
            .where.not(message: [nil, ""])
            .order(id: :desc)
            .limit(HISTORY_LIMIT)
            .pluck(:user_id, :message)
            .reverse
            .map do |user_id, content|
              {
                "role" => user_id == @conversation.bot_user_id ? "assistant" : "user",
                "content" => content,
              }
            end
        end
      end
    end
  end
end
