# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Post
      class V1 < NodeType
        OPERATIONS = %w[create edit get list].freeze
        STATUS_OPTIONS = %w[
          any
          open
          closed
          archived
          listed
          unlisted
          deleted
          public
          noreplies
          single_user
        ].freeze
        POST_TYPE_OPTIONS = %w[regular all first reply moderator_action small_action whisper].freeze
        ORDER_OPTIONS = %w[latest oldest latest_topic oldest_topic likes].freeze
        DEFAULT_LIMIT = 30
        MAX_LIMIT = 800

        def self.list_string_property(control: nil, hidden: false)
          property = {
            type: :string,
            required: false,
            display_options: {
              show: {
                operation: ["list"],
              },
            },
          }

          ui = {}
          ui[:control] = control if control
          ui[:hidden] = true if hidden
          property[:ui] = ui if ui.present?

          property
        end

        description(
          name: "action:post",
          version: "1.0",
          defaults: {
            icon: "reply",
            color: "teal",
          },
          group: "discourse_actions",
          capabilities: {
            run_scope: "per_item",
          },
          output_contracts: [{ schema: Schema::POST_SCHEMA }],
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
                  operation: %w[create edit],
                },
              },
            },
            reply_to_post_number: {
              type: :integer,
              required: false,
              display_options: {
                show: {
                  operation: ["create"],
                },
              },
            },
            whisper: {
              type: :boolean,
              required: false,
              default: false,
              ui: {
                control: :boolean,
                expression: true,
              },
              display_options: {
                show: {
                  operation: ["create"],
                },
              },
            },
            author_username: {
              type: :string,
              required: false,
              default: "system",
              ui: {
                control: :actor,
              },
              display_options: {
                show: {
                  operation: ["create"],
                },
              },
            },
            post_id: {
              type: :string,
              required: true,
              display_options: {
                show: {
                  operation: %w[edit get],
                },
              },
            },
            editor_username: {
              type: :string,
              required: false,
              default: "system",
              ui: {
                control: :actor,
              },
              display_options: {
                show: {
                  operation: ["edit"],
                },
              },
            },
            query: {
              type: :string,
              required: false,
              ui: {
                control: :filter_query,
                filter: :posts,
              },
              display_options: {
                show: {
                  operation: ["list"],
                },
              },
            },
            include_raw: {
              type: :boolean,
              required: false,
              default: true,
              ui: {
                control: :boolean,
              },
              display_options: {
                show: {
                  operation: %w[get list],
                },
              },
            },
            include_cooked: {
              type: :boolean,
              required: false,
              default: false,
              ui: {
                control: :boolean,
              },
              display_options: {
                show: {
                  operation: %w[get list],
                },
              },
            },
            body_character_limit: {
              type: :integer,
              required: false,
              default: 0,
              display_options: {
                show: {
                  operation: %w[get list],
                },
              },
            },
            created_after: list_string_property(hidden: true),
            created_before: list_string_property(hidden: true),
            topic_created_after: list_string_property(hidden: true),
            topic_created_before: list_string_property(hidden: true),
            categories: list_string_property(control: :category, hidden: true),
            exclude_categories: list_string_property(hidden: true),
            exact_category_match: {
              type: :boolean,
              required: false,
              default: false,
              ui: {
                control: :boolean,
                hidden: true,
              },
              display_options: {
                show: {
                  operation: ["list"],
                },
              },
            },
            tags: list_string_property(control: :tags, hidden: true),
            exclude_tags: list_string_property(control: :tags, hidden: true),
            topics: list_string_property(hidden: true),
            usernames: list_string_property(hidden: true),
            groups: list_string_property(hidden: true),
            post_type: {
              type: :options,
              required: false,
              options: POST_TYPE_OPTIONS,
              default: "regular",
              ui: {
                hidden: true,
              },
              display_options: {
                show: {
                  operation: ["list"],
                },
              },
            },
            status: {
              type: :options,
              required: false,
              options: STATUS_OPTIONS,
              default: "any",
              ui: {
                hidden: true,
              },
              display_options: {
                show: {
                  operation: ["list"],
                },
              },
            },
            keywords: list_string_property(hidden: true),
            topic_keywords: list_string_property(hidden: true),
            order: {
              type: :options,
              required: false,
              options: ORDER_OPTIONS,
              default: "latest",
              ui: {
                hidden: true,
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
              min: 1,
              max: MAX_LIMIT,
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
            advanced_filter: {
              type: :string,
              required: false,
              ui: {
                control: :textarea,
                hidden: true,
              },
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
              display_options: {
                show: {
                  operation: %w[get list],
                },
              },
            },
          },
        )

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.flat_map.with_index do |_item, item_index|
              config = config_for(exec_ctx, item_index)
              Array.wrap(execute_with_config(exec_ctx, config, item_index))
            end

          [items]
        end

        private

        def config_for(exec_ctx, item_index)
          {
            "operation" => exec_ctx.get_node_parameter("operation", item_index, default: "create"),
            "topic_id" => exec_ctx.get_node_parameter("topic_id", item_index),
            "raw" => exec_ctx.get_node_parameter("raw", item_index),
            "reply_to_post_number" =>
              exec_ctx.get_node_parameter("reply_to_post_number", item_index),
            "whisper" => exec_ctx.get_node_parameter("whisper", item_index, default: false),
            "post_id" => exec_ctx.get_node_parameter("post_id", item_index),
            "editor_username" => exec_ctx.get_node_parameter("editor_username", item_index),
            "include_raw" => exec_ctx.get_node_parameter("include_raw", item_index, default: true),
            "include_cooked" =>
              exec_ctx.get_node_parameter("include_cooked", item_index, default: false),
            "body_character_limit" =>
              exec_ctx.get_node_parameter("body_character_limit", item_index, default: 0),
            "query" => exec_ctx.get_node_parameter("query", item_index),
            "created_after" => exec_ctx.get_node_parameter("created_after", item_index),
            "created_before" => exec_ctx.get_node_parameter("created_before", item_index),
            "topic_created_after" => exec_ctx.get_node_parameter("topic_created_after", item_index),
            "topic_created_before" =>
              exec_ctx.get_node_parameter("topic_created_before", item_index),
            "categories" => exec_ctx.get_node_parameter("categories", item_index),
            "exclude_categories" => exec_ctx.get_node_parameter("exclude_categories", item_index),
            "exact_category_match" =>
              exec_ctx.get_node_parameter("exact_category_match", item_index),
            "tags" => exec_ctx.get_node_parameter("tags", item_index),
            "exclude_tags" => exec_ctx.get_node_parameter("exclude_tags", item_index),
            "topics" => exec_ctx.get_node_parameter("topics", item_index),
            "usernames" => exec_ctx.get_node_parameter("usernames", item_index),
            "groups" => exec_ctx.get_node_parameter("groups", item_index),
            "post_type" => exec_ctx.get_node_parameter("post_type", item_index, default: "regular"),
            "status" => exec_ctx.get_node_parameter("status", item_index, default: "any"),
            "keywords" => exec_ctx.get_node_parameter("keywords", item_index),
            "topic_keywords" => exec_ctx.get_node_parameter("topic_keywords", item_index),
            "order" => exec_ctx.get_node_parameter("order", item_index, default: "latest"),
            "limit" => exec_ctx.get_node_parameter("limit", item_index, default: DEFAULT_LIMIT),
            "offset" => exec_ctx.get_node_parameter("offset", item_index, default: 0),
            "advanced_filter" => exec_ctx.get_node_parameter("advanced_filter", item_index),
          }
        end

        def execute_with_config(exec_ctx, config, item_index)
          case config["operation"]
          when "create"
            wrap(create_post(exec_ctx, config, item_index))
          when "edit"
            wrap(edit_post(exec_ctx, config, item_index))
          when "get"
            wrap(get_post(exec_ctx, config, item_index))
          when "list"
            list_posts(exec_ctx, config, item_index).map { |data| wrap(data) }
          else
            raise_node_error!(
              I18n.t(
                "discourse_workflows.errors.post.unknown_operation",
                operation: config["operation"],
              ),
            )
          end
        end

        def create_post(exec_ctx, config, item_index)
          actor = exec_ctx.actor_from_parameter("author_username", item_index)
          post =
            exec_ctx.create_post(
              user: actor,
              raw: config["raw"],
              topic_id: config["topic_id"],
              reply_to_post_number: config["reply_to_post_number"],
              whisper: config["whisper"],
            )

          {
            post:
              exec_ctx.serialize_post(
                post,
                guardian: actor.guardian,
                include_raw: true,
                include_cooked: true,
              ),
          }
        end

        def edit_post(exec_ctx, config, item_index)
          editor = exec_ctx.actor_from_parameter("editor_username", item_index)
          post = exec_ctx.edit_post(user: editor, post_id: config["post_id"], raw: config["raw"])

          {
            post:
              exec_ctx.serialize_post(
                post,
                guardian: editor.guardian,
                include_raw: true,
                include_cooked: true,
              ),
          }
        end

        def get_post(exec_ctx, config, item_index)
          post = ::Post.find(config["post_id"])
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          raise Discourse::InvalidAccess if !actor.guardian.can_see?(post)

          { post: serialized_post(exec_ctx, post, guardian: actor.guardian, config: config) }
        end

        def list_posts(exec_ctx, config, item_index)
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          limit = bounded_integer(config["limit"], default: DEFAULT_LIMIT, min: 1, max: MAX_LIMIT)
          offset = bounded_integer(config["offset"], default: 0, min: 0)
          query = query_from_config(config)
          filter = PostsFilter.new(query, guardian: actor.guardian, limit: limit, offset: offset)

          if filter.invalid_filters.present?
            raise_node_error!(
              I18n.t(
                "discourse_workflows.errors.post.invalid_filter",
                fragments: filter.invalid_filters.join(" "),
              ),
            )
          end

          posts = filter.search.includes(:user, topic: %i[category tags])
          posts.map do |post|
            { post: serialized_post(exec_ctx, post, guardian: actor.guardian, config: config) }
          end
        end

        def serialized_post(exec_ctx, post, guardian:, config:)
          data =
            exec_ctx.serialize_post(
              post,
              guardian: guardian,
              include_raw: config["include_raw"],
              include_cooked: config["include_cooked"],
            )

          truncate_body_fields(data, config["body_character_limit"])
        end

        def truncate_body_fields(data, limit)
          limit = bounded_integer(limit, default: 0, min: 0)
          return data if limit <= 0

          %i[raw cooked].each do |field|
            value = data[field]
            next if !value.is_a?(String) || value.length <= limit

            data[field] = truncate_middle(value, limit)
            data[:"#{field}_truncated"] = true
            data[:"#{field}_original_length"] = value.length
          end

          data
        end

        def truncate_middle(value, limit)
          return "" if limit <= 0

          head_length = (limit / 2.0).ceil
          tail_length = limit - head_length
          characters = value.each_char.to_a
          characters.first(head_length).join + characters.last(tail_length).join
        end

        def query_from_config(config)
          query = config["query"].to_s.strip
          return query if query.present?

          parts = []
          add_query_part(parts, "after", config["created_after"])
          add_query_part(parts, "before", config["created_before"])
          add_query_part(parts, "topic_after", config["topic_created_after"])
          add_query_part(parts, "topic_before", config["topic_created_before"])
          add_category_part(
            parts,
            "category",
            config["categories"],
            exact: config["exact_category_match"],
          )
          add_category_part(
            parts,
            "exclude_category",
            config["exclude_categories"],
            exact: config["exact_category_match"],
          )
          add_query_part(parts, "tag", config["tags"])
          add_query_part(parts, "exclude_tag", config["exclude_tags"])
          add_query_part(parts, "topics", config["topics"])
          add_query_part(parts, "usernames", config["usernames"])
          add_query_part(parts, "groups", config["groups"])
          add_query_part(parts, "keywords", config["keywords"])
          add_query_part(parts, "topic_keywords", config["topic_keywords"])
          if POST_TYPE_OPTIONS.include?(config["post_type"]) && config["post_type"] != "regular"
            add_query_part(parts, "post_type", config["post_type"])
          end
          if STATUS_OPTIONS.include?(config["status"]) && config["status"] != "any"
            add_query_part(parts, "status", config["status"])
          end
          add_query_part(parts, "order", config["order"]) if ORDER_OPTIONS.include?(config["order"])

          advanced_filter = config["advanced_filter"].to_s.strip
          parts << advanced_filter if advanced_filter.present?
          parts.join(" ")
        end

        def add_query_part(parts, key, value)
          normalized = list_value(value)
          parts << "#{key}:#{normalized}" if normalized.present?
        end

        def add_category_part(parts, key, value, exact:)
          normalized = list_value(value)
          return if normalized.blank?

          if exact
            normalized =
              normalized
                .split(",")
                .map { |part| part.start_with?("=") ? part : "=#{part}" }
                .join(",")
          end
          parts << "#{key}:#{normalized}"
        end

        def list_value(value)
          Array
            .wrap(value)
            .flat_map { |item| item.to_s.split(",") }
            .map(&:strip)
            .reject(&:blank?)
            .map { |item| quote_query_value(item) }
            .join(",")
        end

        def quote_query_value(value)
          return value if value.match?(/\A["'].*["']\z/)
          return value if !value.match?(/\s/)

          %("#{value.delete('"')}")
        end

        def bounded_integer(value, default:, min:, max: nil)
          integer = Integer(value.presence || default)
          integer = [integer, min].max
          integer = [integer, max].min if max
          integer
        rescue ArgumentError, TypeError
          default
        end
      end
    end
  end
end
