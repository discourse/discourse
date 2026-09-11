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
    EXTERNAL_SIDE_EFFECT = {
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: false,
      openWorldHint: true,
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

    def register_tool(registry, identifier, implementation:, **attributes)
      registry.register_tool(
        identifier,
        implementation:,
        output_schema: implementation::OUTPUT_SCHEMA,
        **attributes,
      )
    end

    def register!
      registry = DiscourseMcp.registry
      register_read_tools(registry)
      register_write_tools(registry)
      register_resources(registry)
      register_prompts(registry)
    end

    def register_read_tools(registry)
      register_tool(
        registry,
        "discourse_current_user_get",
        title: "Get current user",
        description:
          "Returns the authenticated Discourse user, granted scopes, and MCP server URI.",
        implementation: Tools::CurrentUser,
        required_scopes: [DiscourseMcp::INITIAL_SCOPE],
        annotations: READ_ONLY,
      )
      register_tool(
        registry,
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
              max_results: {
                type: "integer",
                minimum: 1,
                maximum: 50,
                default: 10,
              },
            },
            required: %w[query],
          ),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      register_tool(
        registry,
        "discourse_filter_topics",
        title: "Filter topics",
        description:
          "Discover topics through a filtered, top, or hot view. Filtered uses Discourse " \
            "TopicsFilter syntax; top uses Discourse's top score and defaults to weekly; hot " \
            "is daily top. Returns a uniform topic projection and truthful pagination metadata.",
        implementation: Tools::FilterTopics,
        input_schema:
          object_schema(
            {
              filter: {
                type: "string",
                maxLength: 1_000,
              },
              view: {
                type: "string",
                enum: %w[filtered top hot],
                default: "filtered",
              },
              top_period: {
                type: "string",
                enum: Tools::FilterTopics::TOP_PERIODS,
              },
              page: {
                type: "integer",
                minimum: 0,
                default: 0,
              },
              per_page: {
                type: "integer",
                minimum: 1,
                maximum: 50,
                default: 20,
              },
            },
          ),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      register_tool(
        registry,
        "discourse_search_posts",
        title: "Search posts",
        description:
          "Search post-level evidence with Discourse query syntax. Preserves matched posts, " \
            "highlighted excerpts, authors, topics, categories, and bounded continuation. This " \
            "is keyword search, not semantic search.",
        implementation: Tools::SearchPosts,
        input_schema:
          object_schema(
            {
              query: {
                type: "string",
                minLength: 1,
                maxLength: 500,
              },
              page: {
                type: "integer",
                minimum: 1,
                maximum: 10,
                default: 1,
              },
            },
            required: %w[query],
          ),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      register_tool(
        registry,
        "discourse_read_topic_posts",
        title: "Read selected topic posts",
        description:
          "Read exact, earliest, latest, around-post, or username-filtered topic evidence. " \
            "Selection is bounded to 50 posts and reports the visible stream size without " \
            "claiming the entire topic was loaded.",
        implementation: Tools::ReadTopicPosts,
        input_schema:
          object_schema(
            {
              topic_id: {
                type: "integer",
                minimum: 1,
              },
              selection_mode: {
                type: "string",
                enum: %w[latest earliest post_ids around_post usernames],
              },
              limit: {
                type: "integer",
                minimum: 1,
                maximum: 50,
              },
              post_ids: {
                type: "array",
                items: {
                  type: "integer",
                  minimum: 1,
                },
                minItems: 1,
                maxItems: 50,
              },
              post_number: {
                type: "integer",
                minimum: 1,
              },
              usernames: {
                type: "array",
                items: {
                  type: "string",
                  minLength: 1,
                  maxLength: 60,
                },
                minItems: 1,
                maxItems: 50,
              },
              replies_only: {
                type: "boolean",
              },
            },
            required: %w[topic_id selection_mode],
          ),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      register_tool(
        registry,
        "discourse_get_post_replies",
        title: "Get post replies",
        description:
          "Read reply relationships for a post as recursive descendant IDs, bounded rich " \
            "direct replies, or the upstream-bounded ancestor history. Preserves upstream " \
            "ordering and references.",
        implementation: Tools::GetPostReplies,
        input_schema:
          object_schema(
            {
              post_id: {
                type: "integer",
                minimum: 1,
              },
              mode: {
                type: "string",
                enum: %w[reply_ids direct_replies reply_history],
                default: "reply_ids",
              },
              after_post_number: {
                type: "integer",
                minimum: 0,
              },
            },
            required: %w[post_id],
          ),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      register_tool(
        registry,
        "discourse_list_latest_posts",
        title: "List latest posts",
        description:
          "List the site's latest visible posts using Discourse's fixed 50-post page and " \
            "post-ID cursor. Results are a feed, not an exhaustive history.",
        implementation: Tools::ListLatestPosts,
        input_schema:
          object_schema(
            { before_post_id: { type: "integer", minimum: 1 }, replies_only: { type: "boolean" } },
          ),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      register_tool(
        registry,
        "discourse_get_topic_view_stats",
        title: "Get topic view stats",
        description:
          "Get up to 300 ascending daily topic view counts. Views combine anonymous and " \
            "logged-in views; they are not unique viewers or an engagement judgment.",
        implementation: Tools::GetTopicViewStats,
        input_schema:
          object_schema(
            {
              topic_id: {
                type: "integer",
                minimum: 1,
              },
              from: {
                type: "string",
                pattern: "\\A[0-9]{4}-[0-9]{2}-[0-9]{2}\\z",
              },
              to: {
                type: "string",
                pattern: "\\A[0-9]{4}-[0-9]{2}-[0-9]{2}\\z",
              },
            },
            required: %w[topic_id],
          ),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      register_tool(
        registry,
        "discourse_list_directory_items",
        title: "List directory items",
        description:
          "List user-directory metrics with authoritative totals and continuation. Supports " \
            "Discourse periods, ordering, visible groups, page 0-10, and up to 50 rows.",
        implementation: Tools::ListDirectoryItems,
        input_schema:
          object_schema(
            {
              period: {
                type: "string",
                enum: %w[daily weekly monthly quarterly yearly all],
              },
              order: {
                type: "string",
                pattern: "\\A[a-z0-9_]+\\z",
              },
              ascending: {
                type: "boolean",
              },
              group: {
                type: "string",
                minLength: 1,
              },
              page: {
                type: "integer",
                minimum: 0,
                maximum: Tools::ListDirectoryItems::PAGE_LIMIT,
                default: 0,
              },
              limit: {
                type: "integer",
                minimum: 1,
                maximum: Tools::ListDirectoryItems::PAGE_SIZE,
                default: Tools::ListDirectoryItems::PAGE_SIZE,
              },
              name: {
                type: "string",
              },
              username: {
                type: "string",
              },
              exclude_groups: {
                type: "array",
                items: {
                  type: "string",
                  minLength: 1,
                },
                maxItems: 50,
              },
              exclude_usernames: {
                type: "array",
                items: {
                  type: "string",
                  minLength: 1,
                },
                maxItems: 100,
              },
            },
            required: %w[period],
          ),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      register_tool(
        registry,
        "discourse_read_topic",
        title: "Read topic",
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
                maximum: 50,
                default: 5,
              },
              start_post_number: {
                type: "integer",
                minimum: 1,
              },
            },
            required: %w[topic_id],
          ),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      register_tool(
        registry,
        "discourse_read_post",
        title: "Read post",
        description: "Reads one visible post.",
        implementation: Tools::GetPost,
        input_schema:
          object_schema({ post_id: { type: "integer", minimum: 1 } }, required: %w[post_id]),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      register_tool(
        registry,
        "discourse_topic_list",
        title: "List topics",
        description: "Lists recent topics visible to the authenticated user.",
        implementation: Tools::ListTopics,
        input_schema: object_schema({ limit: { type: "integer", minimum: 1, maximum: 50 } }),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      register_tool(
        registry,
        "discourse_category_list",
        title: "List categories",
        description: "Lists the visible category hierarchy.",
        implementation: Tools::ListCategories,
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      register_tool(
        registry,
        "discourse_tag_list",
        title: "List tags",
        description: "Lists visible tags ordered by usage.",
        implementation: Tools::ListTags,
        input_schema: object_schema({ limit: { type: "integer", minimum: 1, maximum: 200 } }),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      register_tool(
        registry,
        "discourse_get_user",
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
      register_tool(
        registry,
        "discourse_list_user_posts",
        title: "List user posts",
        description: "Lists a user's visible topics and replies with zero-based pagination.",
        implementation: Tools::ListUserPosts,
        input_schema:
          object_schema(
            {
              username: {
                type: "string",
                minLength: 1,
                maxLength: 60,
              },
              page: {
                type: "integer",
                minimum: 0,
              },
              limit: {
                type: "integer",
                minimum: 1,
                maximum: 50,
              },
            },
            required: %w[username],
          ),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      register_tool(
        registry,
        "discourse_get_user_summary",
        title: "Get user summary",
        description: "Returns profile-visible aggregate activity for a user.",
        implementation: Tools::GetUserSummary,
        input_schema:
          object_schema(
            { username: { type: "string", minLength: 1, maxLength: 60 } },
            required: %w[username],
          ),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      register_tool(
        registry,
        "discourse_list_user_actions",
        title: "List user actions",
        description: "Lists a user's visible activity using named action types.",
        implementation: Tools::ListUserActions,
        input_schema:
          object_schema(
            {
              username: {
                type: "string",
                minLength: 1,
                maxLength: 60,
              },
              acting_username: {
                type: "string",
                minLength: 1,
                maxLength: 60,
              },
              action_types: {
                type: "array",
                items: {
                  type: "string",
                  enum: Tools::ListUserActions::ACTION_TYPES.keys,
                },
                minItems: 1,
                uniqueItems: true,
              },
              offset: {
                type: "integer",
                minimum: 0,
              },
              limit: {
                type: "integer",
                minimum: 1,
                maximum: 100,
              },
            },
            required: %w[username],
          ),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      register_tool(
        registry,
        "discourse_get_draft",
        title: "Get draft",
        description: "Retrieves one of the authenticated user's drafts by key.",
        implementation: Tools::GetDraft,
        input_schema:
          object_schema(
            {
              draft_key: {
                type: "string",
                minLength: 1,
                maxLength: 40,
              },
              sequence: {
                type: "integer",
                minimum: 0,
              },
            },
            required: %w[draft_key],
          ),
        required_scopes: %w[mcp:drafts:read],
        annotations: READ_ONLY,
      )
      register_tool(
        registry,
        "discourse_bookmark_list",
        title: "List bookmarks",
        description: "Lists the authenticated user's bookmarks.",
        implementation: Tools::ListBookmarks,
        input_schema: object_schema({ limit: { type: "integer", minimum: 1, maximum: 100 } }),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      register_tool(
        registry,
        "discourse_notification_list",
        title: "List notifications",
        description: "Lists the authenticated user's notifications.",
        implementation: Tools::ListNotifications,
        input_schema: object_schema({ limit: { type: "integer", minimum: 1, maximum: 100 } }),
        required_scopes: %w[mcp:content:read],
        annotations: READ_ONLY,
      )
      register_tool(
        registry,
        "discourse_list_private_messages",
        title: "List private messages",
        description: "Lists a personal or group private-message mailbox visible to the user.",
        implementation: Tools::ListPrivateMessages,
        input_schema:
          object_schema(
            {
              username: {
                type: "string",
                minLength: 1,
                maxLength: 60,
              },
              mailbox: {
                type: "string",
                enum: Tools::ListPrivateMessages::MAILBOXES,
                default: "inbox",
              },
              group_name: {
                type: "string",
                minLength: 1,
                maxLength: 100,
              },
              page: {
                type: "integer",
                minimum: 0,
                default: 0,
              },
              per_page: {
                type: "integer",
                minimum: 1,
                maximum: 100,
                default: 30,
              },
            },
          ),
        required_scopes: %w[mcp:private-messages:read],
        annotations: READ_ONLY,
      )
      register_tool(
        registry,
        "discourse_read_private_message",
        title: "Read private message",
        description: "Reads a private message visible to the authenticated user.",
        implementation: Tools::ReadPrivateMessage,
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
                maximum: 50,
                default: 5,
              },
              start_post_number: {
                type: "integer",
                minimum: 1,
              },
            },
            required: %w[topic_id],
          ),
        required_scopes: %w[mcp:private-messages:read],
        annotations: READ_ONLY,
      )
    end

    def register_write_tools(registry)
      register_tool(
        registry,
        "discourse_create_topic",
        title: "Create topic",
        description: "Creates a topic as the authenticated user.",
        implementation: Tools::CreateTopic,
        input_schema:
          object_schema(
            {
              title: {
                type: "string",
                minLength: 1,
                maxLength: 300,
              },
              raw: {
                type: "string",
                minLength: 1,
                maxLength: 30_000,
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
              author_username: {
                type: "string",
                minLength: 1,
                maxLength: 60,
              },
            },
            required: %w[title raw],
          ),
        required_scopes: %w[mcp:content:write],
        annotations: WRITE,
        risk: :write,
      )
      register_tool(
        registry,
        "discourse_create_post",
        title: "Create post",
        description: "Creates a reply in a topic as the authenticated user.",
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
                maxLength: 30_000,
              },
              reply_to_post_number: {
                type: "integer",
                minimum: 1,
              },
              author_username: {
                type: "string",
                minLength: 1,
                maxLength: 60,
              },
            },
            required: %w[topic_id raw],
          ),
        required_scopes: %w[mcp:content:write],
        annotations: WRITE,
        risk: :write,
      )
      register_tool(
        registry,
        "discourse_update_post",
        title: "Update post",
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
                maxLength: 30_000,
              },
              edit_reason: {
                type: "string",
                maxLength: 500,
              },
            },
            required: %w[post_id raw],
          ),
        required_scopes: %w[mcp:content:write],
        annotations: WRITE,
        risk: :write,
      )
      register_tool(
        registry,
        "discourse_update_topic",
        title: "Update topic",
        description: "Updates fields on a topic when the user may edit it.",
        implementation: Tools::UpdateTopic,
        input_schema:
          object_schema(
            {
              topic_id: {
                type: "integer",
                minimum: 1,
              },
              title: {
                type: "string",
                minLength: 1,
                maxLength: 300,
              },
              category_id: {
                type: "integer",
                minimum: 0,
              },
              tags: {
                type: "array",
                items: {
                  type: "string",
                  minLength: 1,
                  maxLength: 100,
                },
                maxItems: 10,
              },
              featured_link: {
                type: "string",
                maxLength: 2_048,
              },
              original_title: {
                type: "string",
                maxLength: 300,
              },
              original_tags: {
                type: "array",
                items: {
                  type: "string",
                  minLength: 1,
                  maxLength: 100,
                },
                maxItems: 10,
              },
            },
            required: %w[topic_id],
          ),
        required_scopes: %w[mcp:content:write],
        annotations: WRITE,
        risk: :write,
      )
      register_tool(
        registry,
        "discourse_update_user",
        title: "Update user",
        description: "Updates the authenticated user's own profile.",
        implementation: Tools::UpdateUser,
        input_schema:
          object_schema(
            {
              username: {
                type: "string",
                minLength: 1,
                maxLength: 60,
              },
              name: {
                type: "string",
                maxLength: 255,
              },
              bio_raw: {
                type: "string",
                maxLength: 3_000,
              },
              location: {
                type: "string",
                maxLength: 1_000,
              },
              website: {
                type: "string",
                maxLength: 2_048,
              },
              title: {
                type: "string",
                maxLength: 255,
              },
              date_of_birth: {
                type: "string",
                format: "date",
              },
              locale: {
                type: "string",
                maxLength: 20,
              },
              profile_background_upload_url: {
                type: "string",
                maxLength: 2_048,
              },
              card_background_upload_url: {
                type: "string",
                maxLength: 2_048,
              },
              upload_id: {
                type: "integer",
                minimum: 1,
              },
            },
            required: %w[username],
          ),
        required_scopes: %w[mcp:profile:write],
        annotations: WRITE,
        risk: :write,
      )
      register_tool(
        registry,
        "discourse_upload_file",
        title: "Upload file",
        description: "Uploads base64 data or a remote HTTP(S) file for the authenticated user.",
        implementation: Tools::UploadFile,
        input_schema:
          object_schema(
            {
              upload_type: {
                type: "string",
                enum: Tools::UploadFile::UPLOAD_TYPES,
              },
              image_data: {
                type: "string",
                minLength: 1,
              },
              url: {
                type: "string",
                minLength: 1,
                maxLength: 2_048,
              },
              filename: {
                type: "string",
                minLength: 1,
                maxLength: 255,
              },
              user_id: {
                type: "integer",
                minimum: 1,
              },
            },
            required: %w[upload_type],
          ),
        required_scopes: %w[mcp:content:write],
        annotations: EXTERNAL_SIDE_EFFECT,
        risk: :external_side_effect,
      )
      register_tool(
        registry,
        "discourse_create_private_message",
        title: "Create private message",
        description: "Creates a private message as the authenticated user.",
        implementation: Tools::CreatePrivateMessage,
        input_schema:
          object_schema(
            {
              title: {
                type: "string",
                minLength: 1,
                maxLength: 300,
              },
              raw: {
                type: "string",
                minLength: 1,
                maxLength: 30_000,
              },
              usernames: {
                type: "array",
                items: {
                  type: "string",
                  minLength: 1,
                  maxLength: 60,
                },
                maxItems: 100,
              },
              group_names: {
                type: "array",
                items: {
                  type: "string",
                  minLength: 1,
                  maxLength: 100,
                },
                maxItems: 100,
              },
              email_addresses: {
                type: "array",
                items: {
                  type: "string",
                  format: "email",
                },
                maxItems: 100,
              },
              author_username: {
                type: "string",
                minLength: 1,
                maxLength: 60,
              },
            },
            required: %w[title raw],
          ),
        required_scopes: %w[mcp:private-messages:write],
        annotations: EXTERNAL_SIDE_EFFECT,
        risk: :external_side_effect,
      )
      register_tool(
        registry,
        "discourse_reply_private_message",
        title: "Reply to private message",
        description: "Replies to a private message visible to the authenticated user.",
        implementation: Tools::ReplyPrivateMessage,
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
                maxLength: 30_000,
              },
              reply_to_post_number: {
                type: "integer",
                minimum: 1,
              },
              author_username: {
                type: "string",
                minLength: 1,
                maxLength: 60,
              },
            },
            required: %w[topic_id raw],
          ),
        required_scopes: %w[mcp:private-messages:write],
        annotations: WRITE,
        risk: :write,
      )
      register_tool(
        registry,
        "discourse_invite_to_private_message",
        title: "Invite to private message",
        description:
          "Adds one user or group, or submits one email invitation, to a private message.",
        implementation: Tools::InviteToPrivateMessage,
        input_schema:
          object_schema(
            {
              topic_id: {
                type: "integer",
                minimum: 1,
              },
              username: {
                type: "string",
                minLength: 1,
                maxLength: 60,
              },
              group_name: {
                type: "string",
                minLength: 1,
                maxLength: 100,
              },
              email_address: {
                type: "string",
                format: "email",
              },
              notify_group_members: {
                type: "boolean",
              },
              custom_message: {
                type: "string",
                minLength: 1,
                maxLength: 3_000,
              },
              author_username: {
                type: "string",
                minLength: 1,
                maxLength: 60,
              },
            },
            required: %w[topic_id],
          ),
        required_scopes: %w[mcp:private-messages:write],
        annotations: EXTERNAL_SIDE_EFFECT,
        risk: :external_side_effect,
      )
      register_tool(
        registry,
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
      register_tool(
        registry,
        "discourse_save_draft",
        title: "Save draft",
        description: "Creates or updates a draft for the authenticated user.",
        implementation: Tools::SaveDraft,
        input_schema:
          object_schema(
            {
              draft_key: {
                type: "string",
                minLength: 1,
                maxLength: 40,
              },
              reply: {
                type: "string",
                minLength: 1,
                maxLength: 50_000,
              },
              title: {
                type: "string",
                minLength: 1,
                maxLength: 300,
              },
              category_id: {
                type: "integer",
                minimum: 1,
              },
              tags: {
                type: "array",
                items: {
                  type: "string",
                  minLength: 1,
                  maxLength: 100,
                },
                maxItems: 10,
              },
              sequence: {
                type: "integer",
                minimum: 0,
                default: 0,
              },
              action: {
                type: "string",
                enum: %w[createTopic reply edit privateMessage],
              },
            },
            required: %w[draft_key reply],
          ),
        required_scopes: %w[mcp:drafts:write],
        annotations: WRITE,
        risk: :write,
      )
      register_tool(
        registry,
        "discourse_delete_draft",
        title: "Delete draft",
        description: "Deletes one of the authenticated user's drafts at its current sequence.",
        implementation: Tools::DeleteDraft,
        input_schema:
          object_schema(
            {
              draft_key: {
                type: "string",
                minLength: 1,
                maxLength: 40,
              },
              sequence: {
                type: "integer",
                minimum: 0,
              },
            },
            required: %w[draft_key sequence],
          ),
        required_scopes: %w[mcp:drafts:write],
        annotations: DESTRUCTIVE,
        risk: :destructive,
      )
      register_tool(
        registry,
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
          text: JSON.generate(ToolHelpers.topic_json(topic, request_context.guardian)),
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
