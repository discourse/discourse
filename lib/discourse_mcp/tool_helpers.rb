# frozen_string_literal: true

module DiscourseMcp
  module ToolHelpers
    MAX_READ_LENGTH = 50_000
    PRIVATE_MESSAGE_DRAFT_ACTION = "privateMessage"

    module_function

    def text_and_structured(value)
      {
        content: [{ type: "text", text: JSON.generate(value) }],
        structuredContent: value,
        isError: false,
      }
    end

    def post_json(post)
      {
        id: post.id,
        topic_id: post.topic_id,
        post_number: post.post_number,
        username: post.username,
        raw: post.raw,
        created_at: post.created_at.iso8601,
        updated_at: post.updated_at.iso8601,
        url: post.full_url,
      }
    end

    def topic_json(topic, guardian, visible_tag_ids: nil)
      visible_tag_ids ||= self.visible_tag_ids([topic], guardian)

      {
        id: topic.id,
        title: topic.title,
        slug: topic.slug,
        category_id: topic.category_id,
        tags: topic.tags.select { |tag| visible_tag_ids.include?(tag.id) }.map(&:name),
        posts_count: topic.posts_count,
        created_at: topic.created_at.iso8601,
        last_posted_at: topic.last_posted_at&.iso8601,
        closed: topic.closed,
        archived: topic.archived,
        url: topic.url,
      }
    end

    def discovery_topic_json(topic, visible_tag_ids)
      posters = topic.posters || topic.posters_summary
      latest_poster = posters.find { |poster| poster.extras.to_s.split.include?("latest") }

      {
        id: topic.id,
        slug: topic.slug,
        title: topic.title,
        category_id: topic.category_id,
        tags: topic.tags.select { |tag| visible_tag_ids.include?(tag.id) }.map(&:name),
        created_at: topic.created_at.iso8601,
        last_posted_at: topic.last_posted_at&.iso8601,
        bumped_at: topic.bumped_at&.iso8601,
        posts_count: topic.posts_count,
        reply_count: topic.reply_count,
        views: topic.views,
        like_count: topic.like_count,
        posters_count: topic.participant_count,
        closed: topic.closed,
        archived: topic.archived,
        pinned: PinnedCheck.pinned?(topic, topic.user_data),
        visible: topic.visible,
        last_poster_username: latest_poster&.user&.username,
        posters:
          posters.map do |poster|
            {
              user_id: poster.user&.id,
              username: poster.user&.username,
              description: poster.description,
            }
          end,
      }
    end

    def evidence_post_json(post, excerpt: nil, include_raw: false)
      user = post.user
      topic = post.topic
      result = {
        id: post.id,
        topic_id: post.topic_id,
        post_number: post.post_number,
        post_type: post.post_type,
        username: user&.username,
        user_id: post.user_id,
        name: SiteSetting.enable_names? ? user&.name : nil,
        created_at: post.created_at.iso8601,
        updated_at: post.updated_at.iso8601,
        excerpt: excerpt,
        reply_to_post_number: post.reply_to_post_number,
        reply_count: post.reply_count,
        like_count: post.like_count,
        category_id: topic&.category_id,
        topic_slug: topic&.slug,
        topic_title: topic&.title,
        staff: user&.staff?,
        moderator: user&.moderator?,
        admin: user&.admin?,
        hidden: post.hidden,
        deleted_at: post.deleted_at&.iso8601,
      }

      if include_raw
        result[:raw] = post.raw.to_s.first(MAX_READ_LENGTH)
        result[:truncated] = post.raw.to_s.length > MAX_READ_LENGTH
      end

      %i[accepted_answer topic_accepted_answer].each do |field|
        result[field] = post.public_send(field) if post.respond_to?(field)
      end
      result
    end

    def visible_tag_ids(topics, guardian)
      DiscourseTagging.visible_tag_ids(topics.flat_map(&:tags), guardian)
    end

    def post_excerpt(post, guardian)
      cooked = ContentLocalization.translated_post_cooked(post, guardian)
      cooked ? Post.excerpt(cooked, nil, post:) : post.excerpt
    end

    def visible_user!(username, guardian)
      user = User.find_by_username(username)
      if user.blank? || !guardian.can_see_profile?(user)
        raise DiscourseMcp::ToolError, I18n.t("mcp.errors.user_not_found")
      end

      user
    end

    def visible_post!(post_id, request_context, access: :read)
      guardian = request_context.guardian
      post = Post.with_deleted.find_by(id: post_id)
      topic = Topic.with_deleted.find_by(id: post&.topic_id)
      post.association(:topic).target = topic if post && topic

      not_found = I18n.t("mcp.errors.post_not_found")
      if post.blank? || topic.blank? || !guardian.can_see?(topic) || !guardian.can_see?(post)
        raise DiscourseMcp::ToolError, not_found
      end

      ensure_private_message_scope!(topic, request_context, access:, not_found:)
      post
    end

    # Finds a topic the request may use, answering exactly like a missing topic
    # when Guardian or the personal-message policy hides it.
    #
    # @param access [Symbol] :read or :write, for the personal-message scope.
    # @returns [Topic]
    def visible_topic!(topic_id, request_context, access: :read)
      topic = Topic.find_by(id: topic_id)
      not_found = I18n.t("mcp.errors.topic_not_found")
      raise ToolError, not_found if topic.blank? || !request_context.guardian.can_see?(topic)

      ensure_private_message_scope!(topic, request_context, access:, not_found:)
      topic
    end

    # Requires the personal-message scope for a personal message. When the
    # content policy turned agent access to personal messages off, the caller's
    # not-found error is raised instead, so the message looks like it doesn't exist.
    #
    # @param not_found [String] The caller's not-found message.
    def ensure_private_message_scope!(topic, request_context, access:, not_found:)
      return unless topic.private_message?

      request_context.ensure_scopes!("mcp:private-messages:#{access}", not_found:)
    end

    # @returns [Boolean] Whether the content policy denies agents every personal message.
    def private_messages_denied?(request_context)
      request_context.content_policy.denies_all?(ContentPolicy::PRIVATE_MESSAGES)
    end

    def private_message_draft?(draft_key, action: nil, archetype: nil)
      topic_id = draft_key.match(/\Atopic_(\d+)\z/)&.captures&.first

      draft_key.start_with?(Draft::NEW_PRIVATE_MESSAGE) || action == PRIVATE_MESSAGE_DRAFT_ACTION ||
        archetype == Archetype.private_message ||
        (
          topic_id.present? &&
            Topic.with_deleted.exists?(id: topic_id.to_i, archetype: Archetype.private_message)
        )
    end

    def ensure_private_message_draft_scope!(
      draft_key,
      request_context,
      access:,
      action: nil,
      archetype: nil,
      not_found: nil
    )
      return if !private_message_draft?(draft_key, action:, archetype:)

      request_context.ensure_scopes!("mcp:private-messages:#{access}", not_found:)
    end

    def ensure_private_message_stored_draft_scope!(draft, request_context, access:, not_found: nil)
      return if draft.blank?

      ensure_private_message_draft_scope!(
        draft.draft_key,
        request_context,
        access:,
        action: draft_action(draft),
        archetype: draft_archetype(draft),
        not_found:,
      )
    end

    # While agent access to personal messages is off, a draft keyed to a topic
    # can only be written while that topic exists and is visible, so a personal
    # message's draft key answers like a missing topic's.
    #
    # @returns [String, nil] The not-found message for a topic key, or nil when
    #   the key doesn't name a topic or personal messages aren't denied.
    def ensure_draft_topic!(draft_key, request_context)
      return if !private_messages_denied?(request_context)

      topic_id = draft_key.match(/\Atopic_(\d+)\z/)&.captures&.first
      return if topic_id.blank?

      not_found = I18n.t("mcp.errors.topic_not_found")
      topic = Topic.with_deleted.find_by(id: topic_id.to_i)
      raise ToolError, not_found if topic.blank? || !request_context.guardian.can_see?(topic)

      not_found
    end

    # While any content rule is active, a tool can't point at an upload that
    # already exists, because the upload may belong to restricted content and
    # nothing yet ties it to what this authorization uploaded.
    #
    # @param references [Array<Object>] Upload ids or upload URLs from the arguments.
    def ensure_no_upload_references!(request_context, *references)
      return if !request_context.content_policy.active? || references.all?(&:blank?)

      raise ToolError, I18n.t("mcp.errors.content_policy_blocked")
    end

    # Drops bookmarks on personal messages and their posts, deleted ones included.
    #
    # @param bookmarks [ActiveRecord::Relation<Bookmark>]
    # @returns [ActiveRecord::Relation<Bookmark>]
    def without_private_message_bookmarks(bookmarks)
      private_topic_ids = Topic.with_deleted.where(archetype: Archetype.private_message).select(:id)
      bookmarks
        .where.not(bookmarkable_type: "Topic", bookmarkable_id: private_topic_ids)
        .where.not(
          bookmarkable_type: "Post",
          bookmarkable_id: Post.with_deleted.where(topic_id: private_topic_ids).select(:id),
        )
    end

    def draft_action(draft)
      data = draft&.parsed_data
      data["action"] if data.is_a?(Hash)
    end

    def draft_archetype(draft)
      data = draft&.parsed_data
      data["archetypeId"] if data.is_a?(Hash)
    end

    def ensure_current_author!(arguments, user)
      requested_author = arguments["author_username"]
      return if requested_author.blank? || requested_author.casecmp?(user.username)

      raise ToolError, I18n.t("mcp.errors.author_must_match", username: user.username)
    end

    # The checks for the first post of a user (fast typing, silence words,
    # silence regex) stay off, as for an API request: a tool call has no
    # typing time.
    def submit_post!(user, **options)
      result = NewPostManager.new(user, options.with_indifferent_access).perform

      if result.failed? || (result.post.nil? && !queued?(result))
        raise ToolError,
              result.errors.full_messages.flatten.to_sentence.presence ||
                I18n.t("mcp.errors.post_not_created")
      end

      result
    end

    def queued?(submission)
      submission.action == :enqueued
    end

    def author_fields(arguments, user)
      requested_author = arguments["author_username"]

      {
        username: user.username,
        requested_author:,
        author_applied: requested_author.present? ? user.username.casecmp?(requested_author) : nil,
      }
    end

    def user_post_json(action)
      {
        id: action.post_id || action.id,
        topic_id: action.topic_id,
        post_number: action.post_number,
        slug: Slug.for(action.title),
        title: action.title,
        created_at: action.created_at&.iso8601,
        excerpt:
          (
            if action.cooked.present?
              PrettyText.excerpt(action.cooked, 300, keep_emoji_images: true)
            else
              nil
            end
          ),
        category_id: action.category_id,
      }
    end
  end
end
