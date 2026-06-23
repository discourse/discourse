# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    module Tools
      class WorkflowNodeCatalog < Base
        TOPIC_LIST_ITEM_SCHEMA = {
          "topic" => "TopicListItemSerializer payload",
          "topic.id" => "integer",
          "topic.title" => "string",
          "topic.fancy_title" => "string",
          "topic.slug" => "string",
          "topic.posts_count" => "integer",
          "topic.category_id" => "integer",
          "topic.tags" => "array<string>",
          "topic.first_post_id" => "integer",
          "topic.closed" => "boolean",
          "topic.archived" => "boolean",
          "topic.created_at" => "datetime",
          "topic.last_posted_at" => "datetime",
          "topic.bumped_at" => "datetime",
        }.freeze

        POST_SCHEMA = {
          "post" => "DiscourseWorkflows::PostSerializer payload",
          "post.id" => "integer",
          "post.raw" => "string",
          "post.post_number" => "integer",
          "post.reply_to_post_number" => "integer|null",
          "post.topic_id" => "integer",
          "post.topic_slug" => "string",
          "post.topic_title" => "string",
          "post.post_url" => "string",
          "post.category_id" => "integer",
          "post.category_name" => "string|null",
          "post.user_id" => "integer",
          "post.username" => "string",
          "post.created_at" => "datetime",
          "post.updated_at" => "datetime",
          "post.excerpt" => "string",
          "post.like_count" => "integer",
          "post.reply_count" => "integer",
          "post.score" => "number|null",
          "post.tags" => "array<string>",
          "post.upload_ids" => "array<integer>",
        }.freeze

        WEBHOOK_POST_SCHEMA =
          POST_SCHEMA.except(
            "post.category_name",
            "post.excerpt",
            "post.like_count",
            "post.tags",
            "post.upload_ids",
          ).merge("post" => "WebHookPostSerializer payload", "post.category_slug" => "string")

        USER_SCHEMA = {
          "user" => "Basic safe user attributes for the post author",
          "user.id" => "integer",
          "user.username" => "string",
          "user.name" => "string|null",
          "user.trust_level" => "integer",
          "user.trust_level_name" => "string",
          "user.admin" => "boolean",
          "user.moderator" => "boolean",
          "user.staff" => "boolean",
        }.freeze

        GROUP_MEMBERSHIP_SCHEMA = {
          "group_membership" => "Group membership check result",
          "group_membership.group_id" => "integer",
          "group_membership.group_name" => "string",
          "group_membership.user_id" => "integer",
          "group_membership.username" => "string",
          "group_membership.in_group" => "boolean",
        }.freeze

        OUTPUT_SCHEMAS = {
          "trigger:manual" => {
          },
          "trigger:topic_admin_button" => TOPIC_LIST_ITEM_SCHEMA,
          "trigger:topic_created" => TOPIC_LIST_ITEM_SCHEMA.merge(POST_SCHEMA),
          "trigger:post_created" => POST_SCHEMA.merge(TOPIC_LIST_ITEM_SCHEMA).merge(USER_SCHEMA),
          "trigger:post_edited" => POST_SCHEMA.merge(TOPIC_LIST_ITEM_SCHEMA).merge(USER_SCHEMA),
          "trigger:topic_closed" => TOPIC_LIST_ITEM_SCHEMA,
          "action:topic" => TOPIC_LIST_ITEM_SCHEMA.merge(WEBHOOK_POST_SCHEMA),
          "action:topic_tags" => {
            "topic_id" => "integer",
            "tag_names" => "array<string>",
          },
          "action:post" => POST_SCHEMA,
          "action:send_personal_message" => TOPIC_LIST_ITEM_SCHEMA.merge(POST_SCHEMA),
          "action:send_chat_message" => {
            "channel_id" => "integer",
            "message" => "string",
          },
          "action:ai_agent" => {
            "result" => "string",
          },
        }.freeze

        EXAMPLES = {
          "action:code" => [
            {
              name: "Add a derived field",
              mode: "runOnceForAllItems",
              code:
                "var items = $input.all();\n" \
                  "items.forEach(function(item) {\n" \
                  "  item.json.summary = item.json.topic && item.json.topic.title;\n" \
                  "});\n" \
                  "return items;",
            },
          ],
          "condition:filter" => [
            {
              name: "Keep TL1 posts mentioning cake",
              parameters: {
                combinator: "and",
                conditions: [
                  {
                    id: "author_trust_level",
                    leftValue: "={{ $json.user.trust_level }}",
                    operator: {
                      operation: "equals",
                      type: "number",
                      singleValue: false,
                    },
                    rightValue: "1",
                  },
                  {
                    id: "post_mentions_cake",
                    leftValue: "={{ $json.post.raw }}",
                    operator: {
                      operation: "contains",
                      type: "string",
                      singleValue: false,
                    },
                    rightValue: "cake",
                  },
                ],
              },
            },
            {
              name: "Keep TL1-or-lower post authors",
              parameters: {
                combinator: "and",
                conditions: [
                  {
                    id: "post_author_trust_level",
                    leftValue: "={{ $json.user.trust_level }}",
                    operator: {
                      operation: "lte",
                      type: "number",
                      singleValue: false,
                    },
                    rightValue: "1",
                  },
                ],
              },
            },
          ],
          "condition:if" => [
            {
              name: "Branch on TL1-or-lower post authors",
              parameters: {
                combinator: "and",
                conditions: [
                  {
                    id: "post_author_trust_level",
                    leftValue: "={{ $json.user.trust_level }}",
                    operator: {
                      operation: "lte",
                      type: "number",
                      singleValue: false,
                    },
                    rightValue: "1",
                  },
                ],
              },
            },
          ],
          "action:group" => [
            {
              name: "Keep posts from members of a group",
              parameters: {
                operation: "check_membership",
                username: "={{ $json.user.username }}",
                group_id: 123,
                actor_username: "system",
              },
            },
          ],
          "action:topic" => [
            {
              name: "Get trigger topic details",
              parameters: {
                operation: "get",
                topic_id: "={{ $json.topic.id }}",
                actor_username: "system",
              },
            },
          ],
          "action:post" => [
            {
              name: "Reply to the trigger topic",
              parameters: {
                operation: "create",
                topic_id: "={{ $json.topic.id }}",
                raw: "Thanks for the report. A staff member will review this soon.",
                author_username: "system",
              },
            },
          ],
          "action:send_personal_message" => [
            {
              name: "DM a post link to an admin",
              parameters: {
                recipient_usernames: ["admin"],
                title: "=New post from @{{ $json.post.username }}",
                raw: "=A group member posted: {{ $json.post.post_url }}",
                sender_username: "system",
              },
            },
          ],
          "action:ai_agent" => [
            {
              name: "Classify the trigger post with an existing agent",
              parameters: {
                agent_id: 123,
                agent_name: "Post classifier",
                runner_username: "system",
                prompt:
                  "=Classify this Discourse post and return a short label: {{ $json.post.raw }}",
              },
            },
          ],
          "action:topic_tags" => [
            {
              name: "Add a tag to the trigger topic",
              parameters: {
                operation: "add",
                topic_id: "={{ $json.topic.id }}",
                tag_names: "needs-review",
                actor_username: "system",
              },
            },
          ],
        }.freeze

        QUERY_STOP_WORDS = %w[
          node
          nodes
          trigger
          triggers
          action
          actions
          condition
          conditions
          flow
        ].freeze

        SEARCH_ALIASES = {
          "action:send_personal_message" => "dm direct message pm personal private message",
          "action:ai_agent" =>
            "ai agent bot llm classify summarize generate sentiment triage runner run as permissions uploads attachments",
          "action:group" => "group membership member belongs friend friends",
        }.freeze

        def self.signature
          {
            name: name,
            description:
              "Lists available Discourse workflow node types with versions, parameters, capabilities, output schemas, and examples.",
            parameters: [
              {
                name: "query",
                description: "Optional search terms for node type, name, group, or parameter names",
                type: "string",
                required: false,
              },
              {
                name: "include_examples",
                description: "Whether to include curated examples for matching nodes",
                type: "boolean",
                required: false,
              },
            ],
          }
        end

        def self.name
          "workflow_node_catalog"
        end

        def self.output_schema_for(identifier, parameters: {}, input_schema: {})
          parameters = parameters.respond_to?(:to_h) ? parameters.to_h.with_indifferent_access : {}

          if identifier.to_s == "action:group" && parameters[:operation].to_s == "check_membership"
            return input_schema.merge(GROUP_MEMBERSHIP_SCHEMA)
          end

          OUTPUT_SCHEMAS.fetch(identifier.to_s, {})
        end

        def invoke
          return not_allowed_response if !ensure_can_manage_workflows!

          query_terms = self.class.query_terms(parameters[:query])
          include_examples =
            parameters[:include_examples].to_s == "true" || parameters[:include_examples] == true

          nodes =
            DiscourseWorkflows::Registry.nodes.filter_map do |node_class|
              serialize_node(node_class, query_terms, include_examples)
            end

          { status: "success", nodes: nodes }
        end

        def self.query_terms(query)
          query
            .to_s
            .downcase
            .scan(/[a-z0-9_:-]+/)
            .map { |term| term.delete_prefix("type:") }
            .reject { |term| QUERY_STOP_WORDS.include?(term) }
            .uniq
        end

        private

        def serialize_node(node_class, query_terms, include_examples)
          description = node_class.description
          identifier = node_class.identifier
          properties = json_safe(node_class.properties || {})
          group = description[:group].to_s.presence

          haystack = [
            identifier,
            group,
            properties.keys.join(" "),
            SEARCH_ALIASES[identifier],
          ].compact.join(" ").downcase
          return if query_terms.present? && query_terms.none? { |term| haystack.include?(term) }

          payload = {
            type: identifier,
            version: node_class.version,
            group: group,
            available: node_class.available?,
            palette_visible: node_class.palette_visible?,
            inputs: json_safe(node_class.inputs),
            outputs: json_safe(node_class.outputs),
            properties: properties,
            credentials: json_safe(node_class.credentials),
            capabilities: json_safe(description[:capabilities] || {}),
            output_schema: self.class.output_schema_for(identifier),
          }
          payload[:examples] = EXAMPLES[identifier] if include_examples && EXAMPLES.key?(identifier)
          payload
        end
      end
    end
  end
end
