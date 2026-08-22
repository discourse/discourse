# frozen_string_literal: true

module DiscourseAi
  module Agents
    class ToolRunner
      # Discourse-side bindings exposed to tool scripts.
      #
      # Auth model — important when extending:
      #
      # Tool scripts are admin-authored but can be invoked by any user who
      # triggers the agent. Bindings here intentionally grant admin-level power
      # to the script. Three non-obvious behaviors to preserve or explicitly
      # revisit if you change them:
      #
      # 1. Source read bindings (`getPost`, `getTopicPost`, `getTopicPosts`,
      #    `getTopic`) default to `system_guardian` for compatibility, but accept
      #    `as_user_id` or `as_username` to scope visibility through that user's
      #    Guardian. `search` and `filterTopics` default to public visibility;
      #    their user scopes expand access and must only use trusted, admin-authored
      #    identities. `with_private: true` uses SystemUser. Scope options are
      #    mutually exclusive and unknown options fail closed with a catchable
      #    JavaScript error. Other privileged reads (`getUser`, `getAgent`) retain
      #    their existing SystemUser behavior.
      #
      # 2. `resolve_guardian` elevates staged users to `system_guardian`. This
      #    supports a seeding pattern exercised by the "can seed a category
      #    with topics and posts" spec: create a staged user, then author
      #    content as them in a category where they'd normally have no write
      #    access. Trade-off: a tool that accepts an externally-influenced
      #    username and hits a staged record runs as system. The preamble
      #    documents this contract; tool authors are expected to treat untrusted
      #    usernames as privilege-relevant.
      #
      # 3. `_discourse_edit_topic` uses `can_see?` as the outer gate. This is
      #    intentional — it's the coarse minimum. Each sub-operation has its
      #    own stricter inner check that matches Discourse core behavior
      #    (e.g. `DiscourseTagging.tag_topic_by_names` allows non-authors to
      #    tag in open-tag categories, which `can_edit?(topic)` would block).
      #    If you add a new sub-operation, add its own inner permission check.
      #    Do not assume the outer `can_see?` is sufficient.
      module Discourse
        MAX_TOPIC_POSTS = 20
        MAX_FILTER_TOPICS = 100
        READ_API_ERROR_KEY = "__discourse_read_error"
        READ_SCOPE_OPTION_KEYS = %i[as_username as_user_id].freeze
        TRUE_BOOLEAN_VALUES = [true, 1, "1", "t", "T", "true", "TRUE", "on", "ON"].freeze
        FALSE_BOOLEAN_VALUES = [
          false,
          nil,
          0,
          "",
          "0",
          "f",
          "F",
          "false",
          "FALSE",
          "off",
          "OFF",
        ].freeze
        TOPIC_POSTS_OPTION_KEYS = [*READ_SCOPE_OPTION_KEYS, :limit, :post_numbers].freeze
        FILTER_TOPICS_OPTION_KEYS = [
          :q,
          :limit,
          :page,
          :with_private,
          *READ_SCOPE_OPTION_KEYS,
        ].freeze
        SEARCH_OPTION_KEYS = [
          :search_query,
          :category,
          :user,
          :order,
          :max_posts,
          :tags,
          :before,
          :after,
          :status,
          :hyde,
          :max_results,
          :result_style,
          :with_private,
          *READ_SCOPE_OPTION_KEYS,
        ].freeze

        def attach_discourse(mini_racer_context)
          mini_racer_context.attach(
            "_discourse_get_post",
            ->(post_id, options) do
              in_read_api_function do
                guardian = resolve_read_guardian(options, allowed_keys: READ_SCOPE_OPTION_KEYS)
                post = Post.find_by(id: positive_integer(post_id, name: "post_id"))
                return nil if post.nil? || !guardian.can_see?(post)
                serialize_post_for_tool(post, scope: guardian)
              end
            end,
          )

          mini_racer_context.attach(
            "_discourse_get_topic_post",
            ->(topic_id, post_number, options) do
              in_read_api_function do
                guardian = resolve_read_guardian(options, allowed_keys: READ_SCOPE_OPTION_KEYS)

                topic = Topic.find_by(id: positive_integer(topic_id, name: "topic_id"))
                return nil if topic.nil? || !guardian.can_see?(topic)

                post =
                  topic.posts.find_by(
                    post_number: positive_integer(post_number, name: "post_number"),
                  )
                return nil if post.nil? || !guardian.can_see?(post)
                serialize_post_for_tool(post, scope: guardian)
              end
            end,
          )

          mini_racer_context.attach(
            "_discourse_get_topic_posts",
            ->(topic_id, options) do
              in_read_api_function do
                options = validate_options(options, allowed_keys: TOPIC_POSTS_OPTION_KEYS)
                guardian = resolve_read_guardian(options, allowed_keys: nil)

                topic = Topic.find_by(id: positive_integer(topic_id, name: "topic_id"))
                return [] if topic.nil? || !guardian.can_see?(topic)

                posts =
                  topic.posts.secured(guardian).joins(:topic).preload(:user).order(:post_number)
                posts = guardian.filter_hidden_posts(posts, category: topic.category)

                if options.key?(:post_numbers)
                  if options.key?(:limit)
                    raise ::Discourse::InvalidParameters.new(
                            "limit and post_numbers cannot be used together",
                          )
                  end
                  unless options[:post_numbers].is_a?(Array)
                    raise ::Discourse::InvalidParameters.new("post_numbers must be an array")
                  end

                  if options[:post_numbers].length > MAX_TOPIC_POSTS
                    raise ::Discourse::InvalidParameters.new(
                            "post_numbers cannot exceed #{MAX_TOPIC_POSTS} entries",
                          )
                  end

                  post_numbers =
                    options[:post_numbers]
                      .map do |post_number|
                        unless post_number.is_a?(Integer) && post_number.positive?
                          raise ::Discourse::InvalidParameters.new(
                                  "post_numbers must contain positive integers",
                                )
                        end
                        post_number
                      end
                      .uniq
                  posts = posts.where(post_number: post_numbers)
                else
                  if options.key?(:limit)
                    limit = positive_integer_option(options[:limit], name: "limit")
                    limit = [limit, MAX_TOPIC_POSTS].min
                  else
                    limit = MAX_TOPIC_POSTS
                  end
                  posts = posts.limit(limit)
                end

                serialized_topic = serialize_listable_topic_for_tool(topic, scope: guardian)
                posts.map do |post|
                  serialize_post_for_tool(post, scope: guardian, serialized_topic: serialized_topic)
                end
              end
            end,
          )

          mini_racer_context.attach(
            "_discourse_get_topic",
            ->(topic_id, options) do
              in_read_api_function do
                guardian = resolve_read_guardian(options, allowed_keys: READ_SCOPE_OPTION_KEYS)
                topic = Topic.find_by(id: positive_integer(topic_id, name: "topic_id"))
                return nil if topic.nil? || !guardian.can_see?(topic)
                serialize_topic_for_tool(topic, scope: guardian)
              end
            end,
          )

          mini_racer_context.attach(
            "_discourse_filter_topics",
            ->(params) do
              in_read_api_function do
                params = validate_options(params, allowed_keys: FILTER_TOPICS_OPTION_KEYS)
                query = params[:q].to_s
                if query.blank?
                  raise ::Discourse::InvalidParameters.new("Missing required parameter: q")
                end

                page = params.key?(:page) ? non_negative_integer(params[:page], name: "page") : 0

                guardian =
                  resolve_read_guardian(
                    params,
                    allowed_keys: nil,
                    default_guardian: Guardian.new,
                    allow_with_private: true,
                  )

                query_options = { guardian: guardian, q: query, page: page }
                if params.key?(:limit)
                  requested_limit = positive_integer_option(params[:limit], name: "limit")
                  query_options[:per_page] = [requested_limit, MAX_FILTER_TOPICS].min
                end

                topic_list = TopicQuery.new(guardian.user, **query_options).list_filter

                {
                  query: query,
                  page: page,
                  limit: topic_list.per_page,
                  topics:
                    topic_list.topics.map do |topic|
                      serialize_topic_for_tool(topic, scope: guardian)
                    end,
                }
              end
            end,
          )

          mini_racer_context.attach(
            "_discourse_get_user",
            ->(user_id_or_username) do
              in_attached_function do
                user = nil

                if user_id_or_username.is_a?(Integer) ||
                     user_id_or_username.to_i.to_s == user_id_or_username
                  user = User.find_by(id: user_id_or_username.to_i)
                else
                  user = User.find_by(username: user_id_or_username)
                end

                return nil if user.nil?

                recursive_as_json(UserSerializer.new(user, scope: system_guardian, root: false))
              end
            end,
          )

          mini_racer_context.attach(
            "_discourse_respond_to_agent",
            ->(agent_name, params) do
              in_attached_function do
                # if we have 1000s of agents this can be slow ... we may need to optimize
                agent_class = AiAgent.all_agents.find { |agent| agent.name == agent_name }
                return { error: "Agent not found" } if agent_class.nil?

                agent = agent_class.new
                bot = DiscourseAi::Agents::Bot.as(@bot_user || agent.user, agent: agent)
                playground = DiscourseAi::AiBot::Playground.new(bot)

                if @context.post_id
                  post = Post.find_by(id: @context.post_id)
                  return { error: "Post not found" } if post.nil?

                  reply_post =
                    playground.reply_to(
                      post,
                      custom_instructions: params["instructions"],
                      whisper: params["whisper"],
                    )

                  if reply_post
                    return(
                      { success: true, post_id: reply_post.id, post_number: reply_post.post_number }
                    )
                  else
                    return { error: "Failed to create reply" }
                  end
                elsif @context.message_id && @context.channel_id
                  message = Chat::Message.find_by(id: @context.message_id)
                  channel = Chat::Channel.find_by(id: @context.channel_id)
                  return { error: "Message or channel not found" } if message.nil? || channel.nil?

                  reply =
                    playground.reply_to_chat_message(message, channel, @context.context_post_ids)

                  if reply
                    return { success: true, message_id: reply.id }
                  else
                    return { error: "Failed to create chat reply" }
                  end
                else
                  return { error: "No valid context for response" }
                end
              end
            end,
          )

          mini_racer_context.attach(
            "_discourse_create_chat_message",
            ->(params) do
              in_attached_function do
                params = params.symbolize_keys
                channel_name = params[:channel_name]
                username = params[:username]
                message = params[:message]

                return { error: "Missing required parameter: channel_name" } if channel_name.blank?
                return { error: "Missing required parameter: message" } if message.blank?

                user, guardian = resolve_guardian(username)
                return { error: "User not found: #{username}" } if user.nil?

                channel = Chat::Channel.find_by(name: channel_name)
                channel ||= Chat::Channel.find_by(slug: channel_name.parameterize)
                return { error: "Channel not found: #{channel_name}" } if channel.nil?

                begin
                  message =
                    ChatSDK::Message.create(
                      raw: message,
                      channel_id: channel.id,
                      guardian: guardian,
                      enforce_membership: !channel.direct_message_channel?,
                    )

                  {
                    success: true,
                    message_id: message.id,
                    message: message.message,
                    created_at: message.created_at.iso8601,
                  }
                rescue => e
                  { error: "Failed to create chat message: #{e.message}" }
                end
              end
            end,
          )

          mini_racer_context.attach(
            "_discourse_create_staged_user",
            ->(params) do
              in_attached_function do
                params = params.symbolize_keys
                email = params[:email]
                username = params[:username]
                name = params[:name]

                # Validate parameters
                return { error: "Missing required parameter: email" } if email.blank?
                return { error: "Missing required parameter: username" } if username.blank?

                # Check if user already exists
                existing_user = User.find_by_email(email) || User.find_by_username(username)
                return { error: "User already exists", user_id: existing_user.id } if existing_user

                begin
                  user =
                    User.create!(
                      email: email,
                      username: username,
                      name: name || username,
                      staged: true,
                      approved: true,
                      trust_level: TrustLevel[0],
                    )

                  { success: true, user_id: user.id, username: user.username, email: user.email }
                rescue => e
                  { error: "Failed to create staged user: #{e.message}" }
                end
              end
            end,
          )

          mini_racer_context.attach(
            "_discourse_create_topic",
            ->(params) do
              in_attached_function do
                params = params.symbolize_keys
                category_name = params[:category_name]
                category_id = params[:category_id]
                title = params[:title]
                raw = params[:raw]
                username = params[:username]
                tags = params[:tags]

                if category_id.blank? && category_name.blank?
                  return { error: "Missing required parameter: category_id or category_name" }
                end
                return { error: "Missing required parameter: title" } if title.blank?
                return { error: "Missing required parameter: raw" } if raw.blank?

                user, guardian = resolve_guardian(username)
                return { error: "User not found: #{username}" } if user.nil?

                category = resolve_category(category_id.presence || category_name)
                return { error: "Category not found" } if category.nil?
                return { error: "Permission denied" } unless guardian.can_create?(Topic, category)

                begin
                  post_creator =
                    PostCreator.new(
                      user,
                      title: title,
                      raw: raw,
                      category: category.id,
                      tags: tags,
                      skip_validations: true,
                      guardian: guardian,
                    )

                  post = post_creator.create

                  if post_creator.errors.present?
                    return { error: post_creator.errors.full_messages.join(", ") }
                  end

                  {
                    success: true,
                    topic_id: post.topic_id,
                    post_id: post.id,
                    topic_slug: post.topic.slug,
                    topic_url: post.topic.url,
                  }
                rescue => e
                  { error: "Failed to create topic: #{e.message}" }
                end
              end
            end,
          )

          mini_racer_context.attach(
            "_discourse_create_post",
            ->(params) do
              in_attached_function do
                params = params.symbolize_keys
                topic_id = params[:topic_id]
                raw = params[:raw]
                username = params[:username]
                reply_to_post_number = params[:reply_to_post_number]

                # Validate parameters
                return { error: "Missing required parameter: topic_id" } if topic_id.blank?
                return { error: "Missing required parameter: raw" } if raw.blank?

                user, guardian = resolve_guardian(username)
                return { error: "User not found: #{username}" } if user.nil?

                topic = Topic.find_by(id: topic_id)
                return { error: "Topic not found" } if topic.nil?
                return { error: "Permission denied" } unless guardian.can_create?(Post, topic)

                begin
                  post_creator =
                    PostCreator.new(
                      user,
                      raw: raw,
                      topic_id: topic_id,
                      reply_to_post_number: reply_to_post_number,
                      skip_validations: true,
                      guardian: guardian,
                    )

                  post = post_creator.create

                  if post_creator.errors.present?
                    return { error: post_creator.errors.full_messages.join(", ") }
                  end

                  {
                    success: true,
                    post_id: post.id,
                    post_number: post.post_number,
                    cooked: post.cooked,
                  }
                rescue => e
                  { error: "Failed to create post: #{e.message}" }
                end
              end
            end,
          )

          mini_racer_context.attach(
            "_discourse_search",
            ->(params) do
              in_read_api_function do
                search_params = validate_options(params, allowed_keys: SEARCH_OPTION_KEYS)
                guardian =
                  resolve_read_guardian(
                    search_params,
                    allowed_keys: nil,
                    default_guardian: Guardian.new,
                    allow_with_private: true,
                  )

                search_params = search_params.except(*READ_SCOPE_OPTION_KEYS, :with_private)
                search_params[:current_user] = guardian.user if guardian.user
                search_params[:result_style] = :detailed
                results = DiscourseAi::Utils::Search.perform_search(**search_params)
                recursive_as_json(results)
              end
            end,
          )

          mini_racer_context.attach(
            "_discourse_get_agent",
            ->(agent_name) do
              in_attached_function do
                agent = AiAgent.find_by(name: agent_name)

                return { error: "Agent not found" } if agent.nil?

                # Return a subset of relevant agent attributes
                {
                  agent:
                    agent.attributes.slice(
                      "id",
                      "name",
                      "description",
                      "enabled",
                      "system_prompt",
                      "temperature",
                      "thinking_effort",
                      "top_p",
                      "vision_enabled",
                      "tools",
                      "allow_chat_channel_mentions",
                      "allow_chat_direct_messages",
                      "allow_topic_mentions",
                      "allow_personal_messages",
                    ),
                }
              end
            end,
          )

          mini_racer_context.attach(
            "_discourse_update_agent",
            ->(agent_id_or_name, updates) do
              in_attached_function do
                # Find agent by ID or name
                agent = nil
                if agent_id_or_name.is_a?(Integer) || agent_id_or_name.to_i.to_s == agent_id_or_name
                  agent = AiAgent.find_by(id: agent_id_or_name.to_i)
                else
                  agent = AiAgent.find_by(name: agent_id_or_name)
                end

                return { error: "Agent not found" } if agent.nil?

                allowed_updates = {}

                if updates["system_prompt"].present?
                  allowed_updates[:system_prompt] = updates["system_prompt"]
                end

                if updates["temperature"].is_a?(Numeric)
                  allowed_updates[:temperature] = updates["temperature"]
                end

                allowed_updates[:top_p] = updates["top_p"] if updates["top_p"].is_a?(Numeric)
                if DiscourseAi::Completions::ThinkingConfig.normalize_effort(
                     updates["thinking_effort"],
                   ) || updates["thinking_effort"] == "default"
                  allowed_updates[:thinking_effort] = updates["thinking_effort"]
                end

                if updates["description"].present?
                  allowed_updates[:description] = updates["description"]
                end

                allowed_updates[:enabled] = updates["enabled"] if updates["enabled"].is_a?(
                  TrueClass,
                ) || updates["enabled"].is_a?(FalseClass)

                if agent.update(allowed_updates)
                  return(
                    {
                      success: true,
                      agent:
                        agent.attributes.slice(
                          "id",
                          "name",
                          "description",
                          "enabled",
                          "system_prompt",
                          "temperature",
                          "thinking_effort",
                          "top_p",
                        ),
                    }
                  )
                else
                  return { error: agent.errors.full_messages.join(", ") }
                end
              end
            end,
          )

          mini_racer_context.attach(
            "_discourse_edit_post",
            ->(post_id, raw, options) do
              in_attached_function do
                post = Post.find_by(id: post_id)
                return { error: "Post not found" } if post.nil?

                options ||= {}
                edit_reason = options["edit_reason"]

                user, guardian = resolve_guardian(options["username"])
                return { error: "User not found: #{options["username"]}" } if user.nil?
                return { error: "Permission denied" } unless guardian.can_edit?(post)

                revisor = PostRevisor.new(post)
                if revisor.revise!(user, { raw: raw, edit_reason: edit_reason })
                  { success: true, post_id: post.id }
                else
                  { error: post.errors.full_messages.join(", ") }
                end
              end
            end,
          )

          mini_racer_context.attach(
            "_discourse_edit_topic",
            ->(topic_id, updates, options) do
              in_attached_function do
                topic = Topic.find_by(id: topic_id)
                return { error: "Topic not found" } if topic.nil?

                updates ||= {}
                options ||= {}

                user, guardian = resolve_guardian(options["username"])
                return { error: "User not found: #{options["username"]}" } if user.nil?
                return { error: "Permission denied" } unless guardian.can_see?(topic)

                # Handle category change
                if updates.key?("category")
                  if topic.private_message?
                    return { error: "Cannot change category of private messages" }
                  end

                  category = resolve_category(updates["category"])
                  return { error: "Category not found" } if category.nil?

                  unless guardian.can_move_topic_to_category?(category.id)
                    return { error: "Permission denied" }
                  end

                  unless topic.change_category_to_id(category.id, silent: !!options["silent"])
                    return(
                      { error: "Failed to change category", details: topic.errors.full_messages }
                    )
                  end
                end

                # Handle visibility change
                if updates.key?("visible")
                  unless guardian.can_toggle_topic_visibility?(topic)
                    return { error: "Permission denied" }
                  end

                  visibility_reason =
                    Topic.visibility_reasons[
                      updates["visible"] ? :manually_relisted : :manually_unlisted
                    ]

                  topic.update_status(
                    "visible",
                    updates["visible"],
                    user,
                    { visibility_reason_id: visibility_reason },
                  )
                end

                # Handle tags change
                if updates.key?("tags")
                  unless DiscourseTagging.tag_topic_by_names(
                           topic,
                           guardian,
                           updates["tags"],
                           append: !!options["append"],
                         )
                    return { error: "Failed to apply tags", details: topic.errors.full_messages }
                  end
                  topic.first_post&.publish_change_to_clients!(:revised)
                end

                {
                  success: true,
                  topic: {
                    id: topic.id,
                    category_id: topic.category_id,
                    category_name: topic.category&.name,
                    category_slug: topic.category&.slug,
                    tags: topic.tags.pluck(:name),
                    visible: topic.visible,
                    visibility_reason_id: topic.visibility_reason_id,
                  },
                }
              end
            end,
          )

          mini_racer_context.attach(
            "_discourse_get_custom_field",
            ->(type, id, key) do
              in_attached_function do
                return { error: "Invalid type: #{type}" } unless CUSTOM_FIELD_MODELS.key?(type)
                model = find_model_by_type(type, id)
                return nil if model.nil?
                model.custom_fields[key]
              end
            end,
          )

          mini_racer_context.attach(
            "_discourse_set_custom_field",
            ->(type, id, key, value) do
              in_attached_function do
                return { error: "Invalid type: #{type}" } unless CUSTOM_FIELD_MODELS.key?(type)
                return { error: "Key is required" } if key.blank?
                if key.to_s.length > MAX_CUSTOM_FIELD_KEY_LENGTH
                  return { error: "Key too long (max #{MAX_CUSTOM_FIELD_KEY_LENGTH} characters)" }
                end
                if value.to_s.length > MAX_CUSTOM_FIELD_VALUE_LENGTH
                  return(
                    { error: "Value too long (max #{MAX_CUSTOM_FIELD_VALUE_LENGTH} characters)" }
                  )
                end

                model = find_model_by_type(type, id)
                return { error: "#{type.capitalize} not found: #{id}" } if model.nil?

                model.custom_fields[key] = value
                model.save_custom_fields

                { success: true, key: key, value: model.custom_fields[key] }
              end
            end,
          )
        end

        private

        def in_read_api_function
          in_attached_function { yield }
        rescue ::Discourse::InvalidParameters, ArgumentError => error
          { READ_API_ERROR_KEY => error.message }
        end

        # Positional IDs historically accept canonical numeric strings; security
        # and collection options remain type-strict.
        def positive_integer(value, name:)
          parsed_value =
            if value.is_a?(Integer)
              value
            elsif value.is_a?(String) && value.match?(/\A\d+\z/)
              value.to_i
            end

          if !parsed_value || !parsed_value.positive?
            raise ::Discourse::InvalidParameters.new("#{name} must be a positive integer")
          end

          parsed_value
        end

        def positive_integer_option(value, name:)
          unless value.is_a?(Integer) && value.positive?
            raise ::Discourse::InvalidParameters.new("#{name} must be a positive integer")
          end

          value
        end

        def non_negative_integer(value, name:)
          unless value.is_a?(Integer) && !value.negative?
            raise ::Discourse::InvalidParameters.new("#{name} must be greater than or equal to 0")
          end

          value
        end

        def boolean_option(value, name:)
          return true if TRUE_BOOLEAN_VALUES.include?(value)
          return false if FALSE_BOOLEAN_VALUES.include?(value)

          raise ::Discourse::InvalidParameters.new("#{name} must be a boolean")
        end

        def validate_options(options, allowed_keys:)
          unless options.respond_to?(:symbolize_keys)
            raise ::Discourse::InvalidParameters.new("options must be an object")
          end

          options = options.symbolize_keys
          unsupported_keys = options.keys - allowed_keys
          if unsupported_keys.present?
            raise ::Discourse::InvalidParameters.new(
                    "Unsupported option(s): #{unsupported_keys.sort.join(", ")}",
                  )
          end

          options
        end

        def resolve_read_guardian(
          options,
          allowed_keys:,
          default_guardian: system_guardian,
          allow_with_private: false
        )
          options = validate_options(options, allowed_keys: allowed_keys) if allowed_keys
          has_username = options.key?(:as_username)
          has_user_id = options.key?(:as_user_id)

          if has_username && has_user_id
            raise ::Discourse::InvalidParameters.new(
                    "as_username and as_user_id cannot be used together",
                  )
          end

          if options.key?(:with_private) && (has_username || has_user_id)
            raise ::Discourse::InvalidParameters.new(
                    "with_private cannot be used with as_username or as_user_id",
                  )
          end

          with_private = false
          if allow_with_private && options.key?(:with_private)
            with_private = boolean_option(options[:with_private], name: "with_private")
          end

          return system_guardian if with_private
          return default_guardian if !has_username && !has_user_id

          user =
            if has_username
              username = options[:as_username]
              unless username.is_a?(String) && username.present?
                raise ::Discourse::InvalidParameters.new("as_username must be a non-empty string")
              end
              User.find_by_username(username)
            else
              user_id = positive_integer_option(options[:as_user_id], name: "as_user_id")
              User.find_by(id: user_id)
            end

          if has_username && user && !user.id.positive?
            raise ::Discourse::InvalidParameters.new(
                    "as_username must identify a user with a positive ID",
                  )
          end

          identity = has_username ? options[:as_username] : options[:as_user_id]
          raise ::Discourse::InvalidParameters.new("User not found: #{identity}") if user.nil?

          Guardian.new(user)
        end

        def resolve_user(username)
          if username.present?
            User.find_by(username: username)
          else
            @bot_user || ::Discourse.system_user
          end
        end

        def resolve_guardian(username)
          user = resolve_user(username)
          return nil, nil if user.nil?
          # Staged users have no standing write permissions, but the seeding
          # pattern (createStagedUser + createTopic/createPost as that user)
          # needs to succeed. Elevate to system_guardian for them. See module
          # header for the contract and trade-off.
          guardian = user.staged? ? system_guardian : Guardian.new(user)
          [user, guardian]
        end

        def resolve_category(category_id_or_name)
          if category_id_or_name.is_a?(Integer) ||
               category_id_or_name.to_i.to_s == category_id_or_name.to_s
            Category.find_by(id: category_id_or_name.to_i)
          else
            Category
              .where(name: category_id_or_name)
              .or(Category.where(slug: category_id_or_name))
              .first
          end
        end

        def serialize_post_for_tool(post, scope:, serialized_topic: nil)
          data =
            recursive_as_json(PostSerializer.new(post, scope: scope, root: false, add_raw: true))
          data["topic"] = serialized_topic ||
            serialize_listable_topic_for_tool(post.topic, scope: scope)
          data
        end

        def serialize_listable_topic_for_tool(topic, scope:)
          recursive_as_json(ListableTopicSerializer.new(topic, scope: scope, root: false))
        end

        def serialize_topic_for_tool(topic, scope:)
          data = serialize_listable_topic_for_tool(topic, scope: scope)
          data["url"] = topic.relative_url
          data["tags"] = topic.tags.map(&:name)
          data["first_post_id"] = topic.first_post&.id
          data["category_id"] = topic.category_id
          data["category_name"] = topic.category&.name
          data["category_slug"] = topic.category&.slug
          data["views"] = topic.views
          data["like_count"] = topic.like_count
          data
        end

        def find_model_by_type(type, id)
          CUSTOM_FIELD_MODELS[type]&.find_by(id: id)
        end
      end
    end
  end
end
