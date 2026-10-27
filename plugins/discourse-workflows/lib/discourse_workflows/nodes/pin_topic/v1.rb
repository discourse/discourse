# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PinTopic
      class V1 < NodeType
        include TopicPinning

        description(
          TopicPinning.description(
            name: "action:pin_topic",
            icon: "thumbtack",
            properties: {
              pinned_globally: {
                type: :boolean,
                required: false,
                default: false,
                ui: {
                  control: :boolean,
                  expression: true,
                },
              },
              pinned_until: {
                type: :string,
                required: false,
                ui: {
                  control: :date_time,
                },
              },
              **TopicPinning::TIMEZONE_PROPERTY,
            },
            output: {
              "pinned_until" => {
                "type" => %w[string null],
                "format" => "date-time",
              },
            },
          ),
        )

        def self.validate_configuration(configuration, errors)
          validate_timezone_configuration(configuration, errors)
        end

        private

        def change(exec_ctx, topic, actor, item_index)
          globally = exec_ctx.get_node_parameter("pinned_globally", item_index, default: false)
          globally = ActiveModel::Type::Boolean.new.cast(globally) || false
          ensure_can_pin!(topic, actor, globally:)
          pinned_until =
            timestamp(
              exec_ctx,
              { "pinned_until" => exec_ctx.get_node_parameter("pinned_until", item_index) },
              "pinned",
              item_index,
            )

          before = topic.slice(:pinned_at, :pinned_globally, :pinned_until)
          topic.update_status(
            globally ? "pinned_globally" : "pinned",
            true,
            actor,
            until: pinned_until,
          )
          topic.reload

          {
            topic: serialize_topic(topic, guardian: actor.guardian),
            pinned_until: topic.pinned_until&.utc&.iso8601,
            changed: topic.slice(:pinned_at, :pinned_globally, :pinned_until) != before,
          }
        end
      end
    end
  end
end
