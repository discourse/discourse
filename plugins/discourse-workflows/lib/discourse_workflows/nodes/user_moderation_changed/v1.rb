# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UserModerationChanged
      class V1 < NodeType
        CHANGES = {
          user_suspended: "suspended",
          user_unsuspended: "unsuspended",
          user_silenced: "silenced",
          user_unsilenced: "unsilenced",
        }.freeze

        OUTPUT_SCHEMA =
          Schema.merge(
            Schema::USER_SCHEMA,
            Schema.document(
              "change" => {
                "type" => "string",
                "enum" => CHANGES.values,
              },
              "actor" => {
                "type" => %w[object null],
                "properties" => Schema::BASIC_USER_PROPERTIES,
              },
              "reason" => {
                "type" => %w[string null],
              },
              "expires_at" => {
                "type" => %w[string null],
                "format" => "date-time",
              },
            ),
          ).freeze

        description(
          name: "trigger:user_moderation_changed",
          version: "1.0",
          defaults: {
            icon: "user-xmark",
            color: "red",
          },
          group: "discourse_triggers",
          event: CHANGES.keys,
          output_contracts: [{ schema: OUTPUT_SCHEMA }],
          properties: {
            changes: {
              type: :multi_options,
              required: false,
              default: [],
              options: CHANGES.values,
            },
          },
          capabilities: {
            provides_current_user: true,
          },
        )

        def self.from_event(event_name, *args)
          new(event_name, *args)
        end

        def initialize(event_name, payload = {})
          super(parameters: {})
          @change = CHANGES[event_name]
          @user = payload[:user]
          @actor = payload[:by_user] || payload[:silenced_by]
          @reason = payload[:reason]
        end

        def valid?
          @change.present? && @user.present? && @user.human?
        end

        def user_id
          @user.id
        end

        def output
          expiry =
            case @change
            when "suspended"
              @user.suspended_till
            when "silenced"
              @user.silenced_till
            end

          {
            user: serialize_user(@user),
            change: @change,
            actor: @actor && serialize_record(@actor, BasicUserSerializer),
            reason: @reason,
            expires_at: expiry&.iso8601,
          }
        end

        def matches?(trigger_ctx)
          changes =
            Array.wrap(trigger_ctx.get_node_parameter("changes", [])).compact_blank.map(&:to_s)
          changes.empty? || changes.include?(@change)
        end
      end
    end
  end
end
