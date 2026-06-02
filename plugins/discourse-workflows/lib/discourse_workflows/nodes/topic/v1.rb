# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Topic
      class V1 < NodeType
        OPERATIONS = %w[create get list close].freeze
        MAX_LIMIT = 100
        DEFAULT_LIMIT = 30

        description(
          name: "action:topic",
          version: "1.0",
          defaults: {
            icon: "comments",
            color: "light-blue",
          },
          group: "discourse_actions",
          capabilities: {
            run_scope: "per_item",
          },
          properties: {
            operation: {
              type: :options,
              required: true,
              options: OPERATIONS,
              default: "create",
            },
            topic_id: {
              type: :string,
              required: true,
              display_options: {
                show: {
                  operation: %w[get close],
                },
              },
            },
            title: {
              type: :string,
              required: true,
              display_options: {
                show: {
                  operation: ["create"],
                },
              },
            },
            raw: {
              type: :string,
              required: true,
              ui: {
                control: :textarea,
              },
              display_options: {
                show: {
                  operation: ["create"],
                },
              },
            },
            category_id: {
              type: :integer,
              required: false,
              ui: {
                control: :category,
              },
              display_options: {
                show: {
                  operation: ["create"],
                },
              },
            },
            tag_names: {
              type: :string,
              required: false,
              ui: {
                control: :tags,
              },
              display_options: {
                show: {
                  operation: ["create"],
                },
              },
            },
            query: {
              type: :string,
              required: true,
              ui: {
                control: :filter_query,
              },
              display_options: {
                show: {
                  operation: ["list"],
                },
              },
            },
            limit: {
              type: :integer,
              required: false,
              default: DEFAULT_LIMIT,
              display_options: {
                show: {
                  operation: ["list"],
                },
              },
            },
            actor_username: {
              type: :string,
              required: false,
              default: "system",
              ui: {
                control: :user,
              },
            },
          },
        )

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.flat_map.with_index do |_item, item_index|
              config = {
                "operation" =>
                  exec_ctx.get_node_parameter("operation", item_index, default: "create"),
                "topic_id" => exec_ctx.get_node_parameter("topic_id", item_index),
                "title" => exec_ctx.get_node_parameter("title", item_index),
                "raw" => exec_ctx.get_node_parameter("raw", item_index),
                "category_id" => exec_ctx.get_node_parameter("category_id", item_index),
                "tag_names" => exec_ctx.get_node_parameter("tag_names", item_index),
                "query" => exec_ctx.get_node_parameter("query", item_index),
                "limit" => exec_ctx.get_node_parameter("limit", item_index, default: DEFAULT_LIMIT),
              }

              Array.wrap(execute_with_config(exec_ctx, config, item_index))
            end

          [items]
        end

        private

        def execute_with_config(exec_ctx, config, item_index)
          case config["operation"]
          when "create"
            wrap(create_topic(exec_ctx, config, item_index))
          when "get"
            wrap(get_topic(exec_ctx, config, item_index))
          when "list"
            list_topics(exec_ctx, config, item_index).map { |data| wrap(data) }
          when "close"
            wrap(close_topic(exec_ctx, config, item_index))
          else
            raise_node_error!(
              I18n.t(
                "discourse_workflows.errors.topic.unknown_operation",
                operation: config["operation"],
              ),
            )
          end
        end

        def create_topic(exec_ctx, config, item_index)
          author = exec_ctx.actor_from_parameter("actor_username", item_index)
          guardian = author.guardian
          category_id = config["category_id"].presence&.to_i
          category = Category.find_by(id: category_id) if category_id
          tag_names = normalize_tag_names(config["tag_names"])

          unless guardian.can_create?(Topic, category)
            raise_node_error!(I18n.t("discourse_workflows.errors.topic.create_failed"))
          end

          args = {
            title: config["title"],
            raw: config["raw"],
            guardian: guardian,
            skip_workflows: true,
          }
          args[:category] = category.id if category
          args[:tags] = tag_names if tag_names.present?

          post_creator = PostCreator.new(author, **args)
          post = post_creator.create
          if post_creator.errors.present?
            raise_node_error!(post_creator.errors.full_messages.join(", "))
          end

          topic = post.topic

          { topic: topic_data(topic, guardian), post_id: post.id, post_number: post.post_number }
        end

        def get_topic(exec_ctx, config, item_index)
          topic = ::Topic.find(config["topic_id"])
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          actor.guardian.ensure_can_see!(topic)
          { topic: topic_data(topic, actor.guardian) }
        end

        def list_topics(exec_ctx, config, item_index)
          limit = [[Integer(config["limit"] || DEFAULT_LIMIT), 1].max, MAX_LIMIT].min
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          topic_query = TopicQuery.new(actor, q: config["query"], per_page: limit)
          topic_list = topic_query.list_filter

          posts = topic_list.topics.map(&:first_post).compact
          if posts.any?
            ActiveRecord::Associations::Preloader.new(records: posts, associations: :user).call
          end

          topic_list.topics.map { |topic| { topic: topic_data(topic, actor.guardian) } }
        end

        def close_topic(exec_ctx, config, item_index)
          topic = ::Topic.find(config["topic_id"])
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          actor.guardian.ensure_can_close_topic!(topic)

          topic.update_status("closed", true, actor)

          { topic: topic_data(topic.reload, actor.guardian) }
        end

        def topic_data(topic, guardian)
          serialize_record(topic, TopicListItemSerializer, scope: guardian)
        end
      end
    end
  end
end
