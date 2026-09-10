# frozen_string_literal: true

module DiscourseMcp
  module CorePrimitives
    READ_ONLY = {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
    }.freeze
    WRITE = {
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: false,
      openWorldHint: false,
    }.freeze
    DESTRUCTIVE = {
      readOnlyHint: false,
      destructiveHint: true,
      idempotentHint: false,
      openWorldHint: false,
    }.freeze

    module_function

    def object_schema(properties = {}, required: [])
      { type: "object", properties: properties, required: required, additionalProperties: false }
    end

    def register!
      registry = DiscourseMcp.registry
      register_read_tools(registry)
      register_write_tools(registry)
      register_resources(registry)
      register_prompts(registry)
    end

    def register_read_tools(registry)
      registry.register_tool(
        "discourse_current_user_get",
        title: "Get current user",
        description:
          "Returns the authenticated Discourse user, granted scopes, and MCP server URI.",
        implementation: Tools::CurrentUser,
        required_scopes: [DiscourseMcp::INITIAL_SCOPE],
        annotations: READ_ONLY,
      )
      registry.register_tool(
        "discourse_search",
        title: "Search Discourse",
        description:
          "Searches topics and posts visible to the authenticated user using Discourse search syntax.",
        implementation: Tools::Search,
        input_schema:
          object_schema(
            {
              query: {
                type: "string",
                minLength: 1,
                maxLength: 500,
              },
              limit: {
                type: "integer",
                minimum: 1,
                maximum: 50,
              },
            },
            required: %w[query],
          ),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      registry.register_tool(
        "discourse_topic_get",
        title: "Get topic",
        description: "Reads a topic and a bounded set of posts visible to the authenticated user.",
        implementation: Tools::GetTopic,
        input_schema:
          object_schema(
            {
              topic_id: {
                type: "integer",
                minimum: 1,
              },
              post_limit: {
                type: "integer",
                minimum: 1,
                maximum: 100,
              },
            },
            required: %w[topic_id],
          ),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      registry.register_tool(
        "discourse_post_get",
        title: "Get post",
        description: "Reads one visible post.",
        implementation: Tools::GetPost,
        input_schema:
          object_schema({ post_id: { type: "integer", minimum: 1 } }, required: %w[post_id]),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      registry.register_tool(
        "discourse_topic_list",
        title: "List topics",
        description: "Lists recent topics visible to the authenticated user.",
        implementation: Tools::ListTopics,
        input_schema: object_schema({ limit: { type: "integer", minimum: 1, maximum: 50 } }),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      registry.register_tool(
        "discourse_category_list",
        title: "List categories",
        description: "Lists the visible category hierarchy.",
        implementation: Tools::ListCategories,
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      registry.register_tool(
        "discourse_tag_list",
        title: "List tags",
        description: "Lists visible tags ordered by usage.",
        implementation: Tools::ListTags,
        input_schema: object_schema({ limit: { type: "integer", minimum: 1, maximum: 200 } }),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      registry.register_tool(
        "discourse_user_get",
        title: "Get user",
        description: "Reads a user profile visible to the authenticated user.",
        implementation: Tools::GetUser,
        input_schema:
          object_schema(
            { username: { type: "string", minLength: 1, maxLength: 60 } },
            required: %w[username],
          ),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      registry.register_tool(
        "discourse_bookmark_list",
        title: "List bookmarks",
        description: "Lists the authenticated user's bookmarks.",
        implementation: Tools::ListBookmarks,
        input_schema: object_schema({ limit: { type: "integer", minimum: 1, maximum: 100 } }),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      registry.register_tool(
        "discourse_notification_list",
        title: "List notifications",
        description: "Lists the authenticated user's notifications.",
        implementation: Tools::ListNotifications,
        input_schema: object_schema({ limit: { type: "integer", minimum: 1, maximum: 100 } }),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
    end

    def register_write_tools(registry)
      registry.register_tool(
        "discourse_topic_create",
        title: "Create topic",
        description: "Creates a topic as the authenticated user.",
        implementation: Tools::CreateTopic,
        input_schema:
          object_schema(
            {
              title: {
                type: "string",
                minLength: 1,
              },
              raw: {
                type: "string",
                minLength: 1,
              },
              category_id: {
                type: "integer",
              },
              tags: {
                type: "array",
                items: {
                  type: "string",
                },
                maxItems: 10,
              },
            },
            required: %w[title raw],
          ),
        required_scopes: %w[mcp:content:write],
        annotations: WRITE,
        risk: :write,
      )
      registry.register_tool(
        "discourse_topic_reply",
        title: "Reply to topic",
        description: "Replies to a topic as the authenticated user.",
        implementation: Tools::ReplyTopic,
        input_schema:
          object_schema(
            {
              topic_id: {
                type: "integer",
                minimum: 1,
              },
              raw: {
                type: "string",
                minLength: 1,
              },
              reply_to_post_number: {
                type: "integer",
                minimum: 1,
              },
            },
            required: %w[topic_id raw],
          ),
        required_scopes: %w[mcp:content:write],
        annotations: WRITE,
        risk: :write,
      )
      registry.register_tool(
        "discourse_post_edit",
        title: "Edit post",
        description: "Edits a post when the authenticated user has permission.",
        implementation: Tools::EditPost,
        input_schema:
          object_schema(
            {
              post_id: {
                type: "integer",
                minimum: 1,
              },
              raw: {
                type: "string",
                minLength: 1,
              },
              edit_reason: {
                type: "string",
                maxLength: 200,
              },
            },
            required: %w[post_id raw],
          ),
        required_scopes: %w[mcp:content:write],
        annotations: WRITE,
        risk: :write,
      )
      registry.register_tool(
        "discourse_post_set_deleted",
        title: "Delete or recover own post",
        description: "Deletes or recovers a post owned by the authenticated user.",
        implementation: Tools::SetPostDeleted,
        input_schema:
          object_schema(
            { post_id: { type: "integer", minimum: 1 }, deleted: { type: "boolean" } },
            required: %w[post_id deleted],
          ),
        required_scopes: %w[mcp:content:write],
        annotations: DESTRUCTIVE,
        risk: :destructive,
      )
      registry.register_tool(
        "discourse_user_status_set",
        title: "Set user status",
        description: "Sets or clears the authenticated user's status.",
        implementation: Tools::SetUserStatus,
        input_schema:
          object_schema(
            {
              clear: {
                type: "boolean",
              },
              description: {
                type: "string",
                maxLength: 100,
              },
              emoji: {
                type: "string",
                maxLength: 100,
              },
              ends_at: {
                type: "string",
                format: "date-time",
              },
            },
          ).merge(
            oneOf: [
              { properties: { clear: { const: true } }, required: %w[clear] },
              { properties: { clear: { enum: [false] } }, required: %w[description emoji] },
            ],
          ),
        required_scopes: %w[mcp:content:write],
        annotations: WRITE,
        risk: :write,
        availability: -> { SiteSetting.enable_user_status },
      )
    end

    def register_resources(registry)
      registry.register_resource_template(
        "discourse.topic",
        title: "Discourse topic",
        description: "A topic visible to the authenticated user.",
        implementation: Resources::Topic,
        input_schema:
          object_schema(
            { uri: { type: "string", pattern: "\\Adiscourse://topic/[0-9]+\\z" } },
            required: %w[uri],
          ),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      registry.register_resource_template(
        "discourse.post",
        title: "Discourse post",
        description: "A post visible to the authenticated user.",
        implementation: Resources::Post,
        input_schema:
          object_schema(
            { uri: { type: "string", pattern: "\\Adiscourse://post/[0-9]+\\z" } },
            required: %w[uri],
          ),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
    end

    def register_prompts(registry)
      registry.register_prompt(
        "discourse.research_topic",
        title: "Research discussions",
        description: "Builds a prompt for researching visible Discourse discussions.",
        implementation: Prompts::ResearchTopic,
        input_schema:
          object_schema(
            { question: { type: "string", minLength: 1, maxLength: 1000 } },
            required: %w[question],
          ),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      registry.register_prompt(
        "discourse.draft_reply",
        title: "Draft a reply",
        description: "Builds a prompt for drafting a grounded reply to a visible topic.",
        implementation: Prompts::DraftReply,
        input_schema:
          object_schema(
            {
              topic_id: {
                type: "integer",
                minimum: 1,
              },
              instructions: {
                type: "string",
                maxLength: 1000,
              },
            },
            required: %w[topic_id],
          ),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
    end
  end

  module Resources
    class Topic
      def self.call(uri:, request_context:)
        id = uri.delete_prefix("discourse://topic/").to_i
        topic = ::Topic.find_by(id: id)
        if topic.blank? || !request_context.guardian.can_see?(topic)
          raise ToolError, "Resource not found"
        end
        {
          uri: uri,
          mimeType: "application/json",
          text: JSON.generate(ToolHelpers.topic_json(topic)),
        }
      end
    end

    class Post
      def self.call(uri:, request_context:)
        id = uri.delete_prefix("discourse://post/").to_i
        post = ::Post.secured(request_context.guardian).find_by(id: id)
        if post.blank? || !request_context.guardian.can_see?(post)
          raise ToolError, "Resource not found"
        end
        { uri: uri, mimeType: "application/json", text: JSON.generate(ToolHelpers.post_json(post)) }
      end
    end
  end

  module Prompts
    class ResearchTopic
      def self.call(arguments:, request_context:)
        {
          description: "Research visible Discourse discussions",
          messages: [
            {
              role: "user",
              content: {
                type: "text",
                text:
                  "Research this question using Discourse search and topic resources. Cite canonical topic and post URLs: #{arguments.fetch("question")}",
              },
            },
          ],
        }
      end
    end

    class DraftReply
      def self.call(arguments:, request_context:)
        topic = ::Topic.find_by(id: arguments.fetch("topic_id").to_i)
        if topic.blank? || !request_context.guardian.can_see?(topic)
          raise ToolError, "Topic not found"
        end
        {
          description: "Draft a reply to #{topic.title}",
          messages: [
            {
              role: "user",
              content: {
                type: "text",
                text:
                  "Read discourse://topic/#{topic.id} and draft a helpful reply. Do not post it. #{arguments["instructions"]}",
              },
            },
          ],
        }
      end
    end
  end
end
