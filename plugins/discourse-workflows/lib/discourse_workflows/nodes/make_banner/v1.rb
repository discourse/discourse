# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module MakeBanner
      class V1 < NodeType
        include TopicPinning

        description(
          TopicPinning.description(
            name: "action:make_banner",
            icon: "bullhorn",
            properties: {
              bannered_until: {
                type: :string,
                required: false,
                ui: {
                  control: :date_time,
                },
              },
              **TopicPinning::TIMEZONE_PROPERTY,
            },
            output: {
              "bannered_until" => {
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
          ensure_can_banner!(topic, actor)
          bannered_until =
            timestamp(
              exec_ctx,
              { "bannered_until" => exec_ctx.get_node_parameter("bannered_until", item_index) },
              "bannered",
              item_index,
            )

          before = topic.slice(:archetype, :bannered_until)
          # Making the current banner the banner again would unbanner it first and fire both events.
          until_time = bannered_until && Time.zone.parse(bannered_until)
          already_banner =
            topic.archetype == ::Archetype.banner && topic.bannered_until&.to_i == until_time&.to_i
          topic.make_banner!(actor, bannered_until) if !already_banner
          topic.reload

          {
            topic: serialize_topic(topic, guardian: actor.guardian),
            bannered_until: topic.bannered_until&.utc&.iso8601,
            changed: topic.slice(:archetype, :bannered_until) != before,
          }
        end
      end
    end
  end
end
