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
            {
              name: "Delete the trigger post",
              parameters: {
                operation: "delete",
                post_id: "={{ $json.post.id }}",
                actor_username: "system",
              },
            },
            {
              name: "Restore a deleted post",
              parameters: {
                operation: "recover",
                post_id: "={{ $json.post.id }}",
                actor_username: "system",
              },
            },
          ],
          "action:send_personal_message" => [
            {
              name: "Send a personal message with a post link to an admin",
              parameters: {
                recipient_usernames: ["admin"],
                title: "=New post from @{{ $json.post.username }}",
                raw: "=A group member posted: {{ $json.post.post_url }}",
                sender_username: "system",
              },
            },
          ],
          "action:send_chat_message" => [
            {
              # Signups are inactive and TL0 when `user_created` fires, so they can't chat yet.
              name: "Welcome a user who reached trust level 1 with a chat DM",
              parameters: {
                target: "user",
                target_usernames: "={{ $json.user.username }}",
                message: "=Welcome to the community, @{{ $json.user.username }}!",
                actor_username: "system",
              },
            },
            {
              name: "Ping the moderators in one group chat DM about a flagged post",
              parameters: {
                target: "group",
                target_usernames: %w[alice bob],
                message: "=Please review {{ $json.post.post_url }}",
                actor_username: "system",
              },
            },
          ],
          "action:send_chat_integration_message" => [
            {
              name: "Send a message to an external chat integration channel",
              parameters: {
                channel_id: 123,
                channel_name: "Slack: #general",
                message: "={{ $json.post.excerpt }}",
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
          "action:tag_group" => [
            {
              name: "Add tags to a tag group",
              parameters: {
                operation: "add",
                tag_group_id: 123,
                tag_names: "needs-review, escalated",
                actor_username: "system",
              },
            },
          ],
          "action:site_setting" => [
            {
              name: "Set a site setting to a templated value",
              parameters: {
                name: "site_description",
                value: "=The friendliest community of {{ $json.year }}",
                actor_username: "system",
              },
            },
          ],
          "action:topic_category" => [
            {
              name: "Move the trigger topic to another category",
              parameters: {
                topic_id: "={{ $json.topic.id }}",
                category_id: 123,
                actor_username: "system",
              },
            },
          ],
          "action:topic_moderation" => [
            {
              name: "Unlist the trigger topic",
              parameters: {
                operation: "unlist_topic",
                topic_id: "={{ $json.topic.id }}",
                actor_username: "system",
              },
            },
          ],
        }.freeze

        MAX_TYPES = 10

        NOTES = {
          "action:code" => [
            "The default value of the code property documents the runtime variables: $input, $json, $(\"Node name\"), $vars, $workflow_vars, $site_settings, $execution, $current_user, $helpers and console.",
            "runOnceForAllItems must return an array of items such as [{ json: { ... } }]; plain objects are normalized under json.",
            "runOnceForEachItem must return one object per input item, not an array, and cannot use $input.first, $input.last, $input.all or $input.itemMatching.",
            "Output items may use the reserved keys json, pairedItem, error and index; do not mix them with plain fields.",
          ],
        }.freeze

        def self.signature
          {
            name: name,
            description:
              "Returns the full definition of the given node types: version, parameters, credentials, capabilities, output contracts, examples and notes. Pick types from the node menu in your instructions.",
            json_schema: {
              type: "object",
              additionalProperties: false,
              required: %w[types],
              properties: {
                types: {
                  type: "array",
                  description:
                    "Exact node type identifiers, such as action:code or trigger:post_created.",
                  items: {
                    type: "string",
                  },
                },
              },
            },
          }
        end

        def self.name
          "workflow_node_catalog"
        end

        def invoke
          return not_allowed_response if !ensure_can_manage_workflows!

          requested = Array.wrap(parameters[:types]).map(&:to_s).uniq
          types = requested.first(MAX_TYPES)
          node_classes =
            types.index_with { |type| DiscourseWorkflows::Registry.latest_node_type(type) }
          node_classes.select! { |_type, node_class| node_class&.palette_visible? }

          result = {
            status: "success",
            nodes: node_classes.values.map { |node_class| serialize_node(node_class) },
            unknown_types: types - node_classes.keys,
          }
          if requested.length > MAX_TYPES
            result[
              :truncated
            ] = "Only the first #{MAX_TYPES} of #{requested.length} requested types are included."
          end
          result
        end

        private

        def serialize_node(node_class)
          identifier = node_class.identifier

          {
            type: identifier,
            version: node_class.version,
            group: node_class.description[:group].to_s.presence,
            available: node_class.available?,
            inputs: json_safe(node_class.inputs),
            outputs: json_safe(node_class.outputs),
            properties: json_safe(node_class.properties || {}),
            credentials: json_safe(node_class.credentials),
            capabilities: json_safe(node_class.description[:capabilities] || {}),
            output_contracts: serialized_output_contracts(node_class),
            examples: EXAMPLES[identifier],
            notes: NOTES[identifier],
          }.compact
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
