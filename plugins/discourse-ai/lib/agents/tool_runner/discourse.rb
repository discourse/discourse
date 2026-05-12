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
      # 1. Read bindings (`getPost`, `getTopic`, `getUser`, `getAgent`) serialize
      #    with `system_guardian` and can return staff-visible data including PMs
      #    and staff-only fields (emails, IPs). `search` and `filterTopics`
      #    default to public visibility and only elevate when `with_private: true`
      #    is passed. Existing tools rely on these contracts — don't tighten or
      #    widen without a corresponding preamble doc change and migration plan.
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
        def attach_discourse(mini_racer_context)
          mini_racer_context.attach(
            "_discourse_get_post",
            ->(post_id) do
              in_attached_function do
                post = Post.find_by(id: post_id)
                return nil if post.nil?
                obj =
                  recursive_as_json(
                    PostSerializer.new(post, scope: system_guardian, root: false, add_raw: true),
                  )
                topic_obj =
                  recursive_as_json(
                    ListableTopicSerializer.new(post.topic, scope: system_guardian, root: false),
                  )
                obj["topic"] = topic_obj
                obj
              end
            end,
          )

          mini_racer_context.attach(
            "_discourse_get_topic",
            ->(topic_id) do
              in_attached_function do
                topic = Topic.find_by(id: topic_id)
                return nil if topic.nil?
                serialize_topic_for_tool(topic, scope: system_guardian)
              end
            end,
          )

          mini_racer_context.attach(
            "_discourse_filter_topics",
            ->(params) do
              in_attached_function do
                return { error: "params must be an object" } if !params.respond_to?(:symbolize_keys)

                params = (params || {}).symbolize_keys
                query = params[:q].to_s
                return { error: "Missing required parameter: q" } if query.blank?

                page = params[:page].to_i
                return { error: "page must be greater than or equal to 0" } if page.negative?

                with_private = ActiveModel::Type::Boolean.new.cast(params[:with_private])
                guardian = with_private ? system_guardian : Guardian.new

                query_options = { guardian: guardian, q: query, page: page }
                query_options[:per_page] = params[:limit].to_i if params.key?(:limit)

                topic_list = TopicQuery.new(nil, **query_options).list_filter

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
              in_attached_function do
                search_params = params.symbolize_keys
                if search_params.delete(:with_private)
                  search_params[:current_user] = ::Discourse.system_user
                end
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
                      "top_p",
                      "vision_enabled",
                      "tools",
                      "max_context_posts",
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

        def serialize_topic_for_tool(topic, scope:)
          data = recursive_as_json(ListableTopicSerializer.new(topic, scope: scope, root: false))
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
