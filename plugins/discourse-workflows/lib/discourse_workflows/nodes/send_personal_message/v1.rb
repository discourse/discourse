# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module SendPersonalMessage
      class V1 < NodeType
        description(
          name: "action:send_personal_message",
          version: "1.0",
          defaults: {
            icon: "envelope",
            color: "teal",
          },
          group: "discourse_actions",
          capabilities: {
            run_scope: "per_item",
          },
          properties: {
            recipient_usernames: {
              type: :array,
              required: false,
              ui: {
                control: :user,
                expression: true,
                multiple: true,
              },
            },
            recipient_group_names: {
              type: :array,
              required: false,
              type_options: {
                load_options_method: "groups",
              },
              ui: {
                control: :group_select,
                expression: true,
                multiple: true,
              },
              control_options: {
                value_property: "name",
                name_property: "name",
                filterable: true,
              },
            },
            title: {
              type: :string,
              required: true,
            },
            raw: {
              type: :string,
              required: true,
              ui: {
                control: :textarea,
              },
            },
            sender_username: {
              type: :string,
              required: false,
              default: "system",
              ui: {
                control: :actor,
              },
            },
          },
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

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map.with_index do |_item, item_index|
              config = {
                "recipient_usernames" =>
                  exec_ctx.get_node_parameter("recipient_usernames", item_index),
                "recipient_group_names" =>
                  exec_ctx.get_node_parameter("recipient_group_names", item_index),
                "title" => exec_ctx.get_node_parameter("title", item_index),
                "raw" => exec_ctx.get_node_parameter("raw", item_index),
              }

              wrap(process(exec_ctx, config, item_index))
            end

          [items]
        end

        private

        def process(exec_ctx, config, item_index)
          sender = exec_ctx.actor_from_parameter("sender_username", item_index)
          post_args = post_args(config)
          post = PostCreator.new(sender, post_args).create!

          {
            topic: topic_data(post.topic, sender.guardian),
            post:
              exec_ctx.serialize_post(
                post,
                guardian: sender.guardian,
                include_raw: true,
                include_cooked: true,
              ),
          }
        end

        def post_args(config)
          recipient_usernames = normalize_recipients(config["recipient_usernames"])
          recipient_group_names = normalize_recipients(config["recipient_group_names"])

          if recipient_usernames.blank? && recipient_group_names.blank?
            raise_node_error!(
              I18n.t("discourse_workflows.errors.send_personal_message.no_recipients"),
            )
          end

          {
            archetype: Archetype.private_message,
            target_usernames: recipient_usernames.presence,
            target_group_names: recipient_group_names.presence,
            title: config["title"],
            raw: config["raw"],
            skip_workflows: true,
          }.compact
        end

        def normalize_recipients(value)
          Array
            .wrap(value)
            .flat_map { |entry| entry.to_s.split(",") }
            .map(&:strip)
            .reject(&:blank?)
            .join(",")
        end

        def topic_data(topic, guardian)
          serialize_record(topic, TopicListItemSerializer, scope: guardian)
        end
      end
    end
  end
end
