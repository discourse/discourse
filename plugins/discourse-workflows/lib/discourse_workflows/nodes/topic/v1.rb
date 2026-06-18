# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Topic
      class V1 < NodeType
        OPERATIONS = %w[create get list close archive set_custom_fields].freeze
        MAX_LIMIT = 100
        DEFAULT_LIMIT = 30
        CUSTOM_FIELD_OPTIONS_LIMIT = 100

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
                  operation: %w[get close archive set_custom_fields],
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
              required: false,
              ui: {
                control: :filter_query,
              },
              display_options: {
                show: {
                  operation: ["list"],
                },
              },
            },
            custom_field_names: {
              type: :multi_options,
              required: false,
              options: [],
              default: [],
              type_options: {
                load_options_depends_on: %w[operation topic_id],
                load_options_method: "topic_custom_fields",
              },
              display_options: {
                show: {
                  operation: %w[get list],
                },
              },
              control_options: {
                value_property: "id",
                name_property: "name",
                filterable: true,
                none: "discourse_workflows.topic.custom_field_names_placeholder",
              },
            },
            custom_fields: {
              type: :fixed_collection,
              required: false,
              type_options: {
                multiple_values: true,
              },
              options: [
                {
                  name: "values",
                  values: {
                    key: {
                      type: :string,
                      required: true,
                      no_data_expression: true,
                    },
                    value: {
                      type: :string,
                      required: true,
                    },
                  },
                },
              ],
              display_options: {
                show: {
                  operation: ["set_custom_fields"],
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
            offset: {
              type: :integer,
              required: false,
              default: 0,
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
                control: :actor,
              },
            },
          },
        )

        def self.load_options_context(context)
          case context.method_name
          when "topic_custom_fields"
            custom_field_scope = ::TopicCustomField.where.not(name: [nil, ""])
            if context.filter.present?
              custom_field_scope =
                custom_field_scope.where(
                  "name ILIKE ?",
                  "%#{ActiveRecord::Base.sanitize_sql_like(context.filter)}%",
                )
            end

            custom_field_scope
              .distinct
              .order(:name)
              .limit(CUSTOM_FIELD_OPTIONS_LIMIT)
              .pluck(:name)
              .map { |name| { id: name, name: name } }
          end
        end

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
                "custom_field_names" =>
                  exec_ctx.get_node_parameter("custom_field_names", item_index, default: []),
                "custom_fields" =>
                  exec_ctx.get_node_parameter("custom_fields.values", item_index, default: []),
                "limit" => exec_ctx.get_node_parameter("limit", item_index, default: DEFAULT_LIMIT),
                "offset" => exec_ctx.get_node_parameter("offset", item_index, default: 0),
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
          when "archive"
            wrap(archive_topic(exec_ctx, config, item_index))
          when "set_custom_fields"
            wrap(set_custom_fields(exec_ctx, config, item_index))
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

          {
            topic: exec_ctx.serialize_topic(topic, guardian: guardian),
            post: post_data(post),
            post_id: post.id,
            post_number: post.post_number,
          }
        end

        def get_topic(exec_ctx, config, item_index)
          topic = ::Topic.find(config["topic_id"])
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          actor.guardian.ensure_can_see!(topic)
          custom_field_names = config["custom_field_names"]
          ::Topic.preload_custom_fields([topic], custom_field_names) if custom_field_names.present?

          {
            topic:
              exec_ctx.serialize_topic(
                topic,
                guardian: actor.guardian,
                custom_field_names: custom_field_names,
              ),
            post: post_data(topic.first_post),
          }
        end

        def list_topics(exec_ctx, config, item_index)
          limit = [[Integer(config["limit"] || DEFAULT_LIMIT), 1].max, MAX_LIMIT].min
          offset = [Integer(config["offset"] || 0), 0].max
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          topic_query =
            TopicQuery.new(
              actor.guardian.user,
              q: config["query"],
              per_page: [limit + offset, MAX_LIMIT].min,
            )
          topic_list = topic_query.list_filter

          topics = topic_list.topics.slice(offset, limit) || []
          posts = topics.map(&:first_post).compact
          if posts.any?
            ActiveRecord::Associations::Preloader.new(records: posts, associations: :user).call
          end

          custom_field_names = config["custom_field_names"]
          ::Topic.preload_custom_fields(topics, custom_field_names) if custom_field_names.present?

          topics.map do |topic|
            {
              topic:
                exec_ctx.serialize_topic(
                  topic,
                  guardian: actor.guardian,
                  custom_field_names: custom_field_names,
                ),
              post: post_data(topic.first_post),
            }
          end
        end

        def close_topic(exec_ctx, config, item_index)
          topic = ::Topic.find(config["topic_id"])
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          actor.guardian.ensure_can_close_topic!(topic)

          topic.update_status("closed", true, actor)

          topic.reload
          {
            topic: exec_ctx.serialize_topic(topic, guardian: actor.guardian),
            post: post_data(topic.first_post),
          }
        end

        def archive_topic(exec_ctx, config, item_index)
          topic = ::Topic.find(config["topic_id"])
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          guardian = actor.guardian
          guardian.ensure_can_archive_topic!(topic)

          topic.update_status("archived", true, actor)

          topic.reload
          {
            topic: exec_ctx.serialize_topic(topic, guardian: guardian),
            post: post_data(topic.first_post),
          }
        end

        def set_custom_fields(exec_ctx, config, item_index)
          topic = ::Topic.find(config["topic_id"])
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          guardian = actor.guardian
          guardian.ensure_can_edit_topic!(topic)

          custom_fields = custom_fields_from_entries(config["custom_fields"])
          if custom_fields.present?
            custom_fields.each { |key, value| topic.custom_fields[key] = value }
            topic.save_custom_fields
          end

          {
            topic:
              exec_ctx.serialize_topic(
                topic,
                guardian: guardian,
                custom_field_names: custom_fields.keys,
              ),
          }
        end

        def custom_fields_from_entries(entries)
          Array(entries).each_with_object({}) do |entry, fields|
            key = entry["key"].to_s.strip
            next if key.blank?

            fields[key] = entry["value"]
          end
        end

        def post_data(post)
          return if post.blank?

          serialize_record(post, WebHookPostSerializer)
        end
      end
    end
  end
end
