# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    module Tools
      class WorkflowNodeCatalog < Base
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
          "action:user" => [
            {
              name: "Look up a post author",
              parameters: {
                operation: "get",
                username: "={{ $json.user.username }}",
                actor_username: "system",
              },
            },
            {
              name: "Set a user title and trust level",
              parameters: {
                operation: "edit",
                username: "={{ $json.user.username }}",
                updates: {
                  title: "Member",
                  trust_level: "2",
                  trust_level_locked: true,
                },
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
          "trigger:user_added_to_group" => "joined added to group membership member",
          "trigger:user_removed_from_group" => "left removed from group membership member",
          "action:user" =>
            "user profile bio title trust level lock groups fields lookup edit update",
        }.freeze

        def self.signature
          {
            name: name,
            description:
              "Lists available Discourse workflow node types with versions, parameters, capabilities, output contracts, and examples.",
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
            output_contracts: serialized_output_contracts(node_class),
          }
          payload[:examples] = EXAMPLES[identifier] if include_examples && EXAMPLES.key?(identifier)
          payload
        end

        def serialized_output_contracts(node_class)
          node_class.output_contracts.map do |contract|
            serialized_output_contract(contract).merge(
              variants:
                contract.fetch(:variants).map { |variant| serialized_output_contract(variant) },
            )
          end
        end

        def serialized_output_contract(contract)
          {
            fields: DiscourseAi::WorkflowSchemaFields.convert(contract.fetch(:schema)),
            mode: contract.fetch(:mode).to_s,
            display_options: json_safe(contract.fetch(:display_options)),
          }
        end
      end
    end
  end
end
