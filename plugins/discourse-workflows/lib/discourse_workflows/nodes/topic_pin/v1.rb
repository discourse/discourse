# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicPin
      class V1 < NodeType
        OPERATIONS = %w[add remove].freeze
        PIN_TYPES = %w[pin banner].freeze

        OUTPUT_SCHEMA = {
          "$schema" => Schema::DRAFT_URI,
          "type" => "object",
          "properties" => {
            "topic_id" => {
              "type" => "integer",
            },
            "pinned" => {
              "type" => "boolean",
            },
            "pinned_globally" => {
              "type" => "boolean",
            },
            "pinned_at" => {
              "type" => %w[string null],
              "format" => "date-time",
            },
            "pinned_until" => {
              "type" => %w[string null],
              "format" => "date-time",
            },
            "banner" => {
              "type" => "boolean",
            },
            "bannered_until" => {
              "type" => %w[string null],
              "format" => "date-time",
            },
          },
        }.freeze

        description(
          name: "action:topic_pin",
          version: "1.0",
          defaults: {
            icon: "thumbtack",
            color: "pink",
          },
          group: "discourse_actions",
          capabilities: {
            run_scope: "per_item",
          },
          output_contracts: [{ schema: OUTPUT_SCHEMA }],
          properties: {
            operation: {
              type: :options,
              required: true,
              options: OPERATIONS,
              default: "add",
              ui: {
                expression: true,
              },
            },
            pin_type: {
              type: :options,
              required: true,
              options: PIN_TYPES,
              default: "pin",
              ui: {
                expression: true,
              },
            },
            topic_id: {
              type: :string,
              required: true,
            },
            pinned_globally: {
              type: :boolean,
              required: false,
              default: false,
              ui: {
                control: :boolean,
                expression: true,
              },
              display_options: {
                show: {
                  operation: ["add"],
                  pin_type: ["pin"],
                },
              },
            },
            pinned_until: {
              type: :string,
              required: false,
              ui: {
                control: :date_time,
              },
              display_options: {
                show: {
                  operation: ["add"],
                  pin_type: ["pin"],
                },
              },
            },
            bannered_until: {
              type: :string,
              required: false,
              ui: {
                control: :date_time,
              },
              display_options: {
                show: {
                  operation: ["add"],
                  pin_type: ["banner"],
                },
              },
            },
            timezone: {
              type: :string,
              required: false,
              ui: {
                control: :timezone,
              },
              control_options: {
                none: "discourse_workflows.topic_pin.timezone_none",
              },
              display_options: {
                show: {
                  operation: ["add"],
                },
              },
            },
            actor_username: {
              type: :string,
              required: false,
              default: "system",
              ui: {
                control: :actor,
              },
            },
          },
        )

        def self.validate_configuration(configuration, errors)
          validate_timezone_configuration(configuration, errors)
        end

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map.with_index do |_item, item_index|
              config = {
                "operation" => exec_ctx.get_node_parameter("operation", item_index, default: "add"),
                "pin_type" => exec_ctx.get_node_parameter("pin_type", item_index, default: "pin"),
                "topic_id" => exec_ctx.get_node_parameter("topic_id", item_index),
                "pinned_globally" =>
                  exec_ctx.get_node_parameter("pinned_globally", item_index, default: false),
                "pinned_until" => exec_ctx.get_node_parameter("pinned_until", item_index),
                "bannered_until" => exec_ctx.get_node_parameter("bannered_until", item_index),
              }

              wrap(process(exec_ctx, config, item_index))
            end

          [items]
        end

        private

        def process(exec_ctx, config, item_index)
          operation =
            validated(
              config["operation"],
              OPERATIONS,
              "discourse_workflows.errors.unknown_operation",
              :operation,
            )
          pin_type =
            validated(
              config["pin_type"],
              PIN_TYPES,
              "discourse_workflows.errors.topic_pin.unknown_pin_type",
              :pin_type,
            )

          topic = ::Topic.find(config["topic_id"])
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)

          if pin_type == "banner"
            change_banner(exec_ctx, topic, actor, operation, config, item_index)
          else
            change_pin(exec_ctx, topic, actor, operation, config, item_index)
          end

          {
            topic_id: topic.id,
            pinned: topic.pinned_at.present?,
            pinned_globally: topic.pinned_globally,
            pinned_at: topic.pinned_at&.utc&.iso8601,
            pinned_until: topic.pinned_until&.utc&.iso8601,
            banner: topic.archetype == ::Archetype.banner,
            bannered_until: topic.bannered_until&.utc&.iso8601,
          }
        end

        def change_pin(exec_ctx, topic, actor, operation, config, item_index)
          globally = operation == "add" && config["pinned_globally"].present?
          ensure_can_pin!(topic, actor, globally: globally)

          if operation == "remove"
            return if topic.pinned_at.blank?
            topic.update_status("pinned", false, actor)
          else
            status = globally ? "pinned_globally" : "pinned"
            until_value = timestamp(exec_ctx, config, "pinned", item_index)
            topic.update_status(status, true, actor, until: until_value)
          end
        end

        def change_banner(exec_ctx, topic, actor, operation, config, item_index)
          ensure_can_banner!(topic, actor)

          if operation == "remove"
            return if topic.archetype != ::Archetype.banner
            topic.remove_banner!(actor)
          else
            topic.make_banner!(actor, timestamp(exec_ctx, config, "bannered", item_index))
          end
        end

        def ensure_can_pin!(topic, actor, globally:)
          guardian = actor.guardian
          allowed = globally ? guardian.can_moderate?(topic) : guardian.can_pin_unpin_topic?(topic)
          return if allowed

          denied!(globally ? "pin_globally_not_allowed" : "pin_not_allowed", actor, topic)
        end

        def ensure_can_banner!(topic, actor)
          return if actor.guardian.can_banner_topic?(topic)

          if topic.private_message?
            raise_node_error!(I18n.t("discourse_workflows.errors.topic_pin.banner_private_message"))
          elsif topic.category&.read_restricted?
            raise_node_error!(
              I18n.t("discourse_workflows.errors.topic_pin.banner_restricted_category"),
            )
          else
            denied!("banner_not_allowed", actor, topic)
          end
        end

        def denied!(key, actor, topic)
          raise_node_error!(
            I18n.t(
              "discourse_workflows.errors.topic_pin.#{key}",
              username: actor.username,
              topic_id: topic.id,
            ),
          )
        end

        def timestamp(exec_ctx, config, prefix, item_index)
          value = config["#{prefix}_until"].to_s.presence
          return if value.nil?

          zone = ActiveSupport::TimeZone[resolve_timezone(exec_ctx, item_index)]
          parsed =
            begin
              zone&.parse(value)
            rescue ArgumentError
              nil
            end

          if parsed.nil?
            raise_node_error!(
              I18n.t(
                "discourse_workflows.errors.topic_pin.invalid_timestamp",
                field: "#{prefix}_until",
                value: value,
              ),
            )
          end

          parsed.iso8601
        end

        def validated(value, allowed, error_key, param)
          value = value.to_s
          return value if allowed.include?(value)

          raise_node_error!(I18n.t(error_key, param => value))
        end
      end
    end
  end
end
