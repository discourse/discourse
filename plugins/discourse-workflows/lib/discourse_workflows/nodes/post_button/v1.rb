# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostButton
      class V1 < NodeType
        POSITION_OPTIONS = %w[first last more_menu relative].freeze
        POSITION_DIRECTION_OPTIONS = %w[before after].freeze
        POSITION_ANCHOR_OPTIONS = %w[
          read
          like
          copy_link
          flag
          edit
          bookmark
          delete
          admin
          reply
          custom
        ].freeze

        description(
          name: "trigger:post_button",
          version: "1.0",
          defaults: {
            icon: "arrow-pointer",
            color: "cyan",
          },
          group: "discourse_triggers",
          properties: {
            label: {
              type: :string,
              required: true,
            },
            icon: {
              type: :icon,
              required: false,
            },
            group_ids: {
              type: :array,
              required: true,
              type_options: {
                load_options_method: "groups",
              },
              ui: {
                control: :group_select,
                multiple: true,
              },
              control_options: {
                value_property: "id",
                name_property: "name",
                filterable: true,
              },
            },
            position: {
              type: :options,
              required: false,
              default: "last",
              options: POSITION_OPTIONS,
            },
            position_direction: {
              type: :options,
              required: false,
              default: "before",
              options: POSITION_DIRECTION_OPTIONS,
              display_options: {
                show: {
                  position: ["relative"],
                },
              },
            },
            position_anchor: {
              type: :options,
              required: false,
              default: "reply",
              options: POSITION_ANCHOR_OPTIONS,
              display_options: {
                show: {
                  position: ["relative"],
                },
              },
            },
            position_custom_key: {
              type: :string,
              required: false,
              display_options: {
                show: {
                  position: ["relative"],
                  position_anchor: ["custom"],
                },
              },
            },
            confirmation: {
              type: :boolean,
              required: false,
              default: false,
            },
            confirmation_message: {
              type: :string,
              required: false,
              display_options: {
                show: {
                  confirmation: [true],
                },
              },
            },
          },
          capabilities: {
            manually_triggerable: true,
            provides_current_user: true,
          },
          output_contracts: [
            { schema: Schema.merge(Schema::POST_SCHEMA, Schema::TOPIC_LIST_ITEM_SCHEMA) },
          ],
        )

        def self.load_options_context(context)
          case context.method_name
          when "groups"
            ::Group
              .order(:name)
              .pluck(:id, :name)
              .select { |_, name| context.matches_filter?(name) }
              .map { |id, name| { id:, name: } }
          end
        end

        def self.normalized_group_ids(parameters)
          Array
            .wrap(parameters["group_ids"])
            .filter_map do |group_id|
              value = group_id.to_s
              value.to_i if value.match?(/\A\d+\z/)
            end
        end

        def self.available_to?(user, parameters)
          return false if user.blank?

          group_ids = normalized_group_ids(parameters)
          group_ids.present? && user.in_any_groups?(group_ids)
        end

        def self.resolved_position(parameters)
          position = parameters["position"].presence || "last"
          return position if position != "relative"

          direction = parameters["position_direction"].presence || "before"
          anchor = parameters["position_anchor"].presence || "reply"
          anchor = parameters["position_custom_key"].to_s.strip.presence if anchor == "custom"
          return "last" if anchor.blank?

          "#{direction}_#{anchor}"
        end

        def initialize(post)
          super(parameters: {})
          @post = post
        end

        def valid?
          @post.present? && @post.topic.present?
        end

        def output
          { post: post_data(@post), topic: topic_data(@post.topic) }
        end

        private

        def post_data(post)
          serialize_post(post)
        end

        def topic_data(topic)
          serialize_record(topic, TopicListItemSerializer)
        end
      end
    end
  end
end
