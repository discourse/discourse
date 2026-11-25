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

      ensure_topic_access!(topic, request_context, access:, not_found:)
      post
    end

    # Finds a topic the request may use, answering exactly like a missing topic
    # when Guardian or the content policy hides it.
    #
    # @param access [Symbol] :read or :write, for the personal-message scope.
    # @returns [Topic]
    def visible_topic!(topic_id, request_context, access: :read)
      topic = Topic.find_by(id: topic_id)
      not_found = I18n.t("mcp.errors.topic_not_found")
      raise ToolError, not_found if topic.blank? || !request_context.guardian.can_see?(topic)

      ensure_topic_access!(topic, request_context, access:, not_found:)
      topic
    end

    # Checks a topic Guardian already lets the user see against the content
    # policy, and requires the personal-message scope for a personal message.
    # A restricted topic, and a personal message while agent access to them is
    # off, raise the caller's not-found error, so they look like they don't exist.
    #
    # @param access [Symbol] :read or :write, for the personal-message scope.
    # @param not_found [String] The caller's not-found message.
    def ensure_topic_access!(topic, request_context, access:, not_found:)
      raise ToolError, not_found if !request_context.content_policy.allows_topic?(topic)
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

    # While a content rule is active, a draft keyed to a topic can only be
    # written while that topic exists and the request may see it, so a
    # restricted topic's draft key answers like a missing topic's.
    #
    # @returns [String, nil] The not-found message for a topic key, or nil when
    #   the key doesn't name a topic or no rule is active.
    def ensure_draft_topic!(draft_key, request_context)
      return if !request_context.content_policy.active?

      topic_id = draft_topic_id(draft_key)
      return if topic_id.blank?

      not_found = I18n.t("mcp.errors.topic_not_found")
      topic = Topic.with_deleted.find_by(id: topic_id)
      if topic.blank? || !request_context.guardian.can_see?(topic) ||
           !request_context.content_policy.allows_topic?(topic)
        raise ToolError, not_found
      end

      not_found
    end

    # Whether a stored draft must read as missing: its key names a topic the
    # policy restricts or that no longer exists, or its saved category does.
    #
    # @param draft_key [String]
    # @param data [Hash, nil] The draft's parsed data.
    # @returns [Boolean]
    def restricted_draft?(draft_key, request_context, data: nil)
      policy = request_context.content_policy
      return false if !policy.active?

      topic_id = draft_topic_id(draft_key)
      return true if topic_id && !policy.allows_topic_id?(topic_id)
      return false if !data.is_a?(Hash)

      category_id = data["categoryId"]
      category_id.is_a?(Integer) && !policy.allows_category_id?(category_id)
    end

    def draft_topic_id(draft_key)
      draft_key.match(/\A#{Draft::EXISTING_TOPIC}(\d+)\z/)&.captures&.first&.to_i
    end

    # The tags a topic would carry once a write stores it: the named tags with
    # synonyms resolved to their targets, the parent tags their tag groups add,
    # and, when `text` is given, the tags its watched words add.
    #
    # While a rule is active, no tag may be created implicitly, so a name that
    # doesn't resolve is refused. The refusal is the same generic error as for
    # a restricted result, so it never tells a missing tag from a denied one.
    #
    # @param tag_names [Array<String>, nil]
    # @param category_id [Integer, nil]
    # @param text [String, nil] The title and raw of a topic being created.
    # @param error [String] The `mcp.errors` key of the refusal.
    # @param guardian [Guardian, nil] Whose permissions the save uses; the caller's by default.
    # @returns [Set<Integer>]
    def prospective_tag_ids!(
      request_context,
      tag_names:,
      category_id:,
      text: nil,
      error: "content_policy_output_blocked",
      guardian: nil
    )
      # The names are resolved by the same steps that save them: the caller's
      # tags first, then, for a new topic, the tags its watched words add to the
      # tags already saved.
      category = Category.find_by(id: category_id)
      names =
        saved_tag_names(tag_param_names(tag_names), guardian || request_context.guardian, category)
      if text.present? && WordWatcher.words_for_action(:tag).present?
        names =
          saved_tag_names(
            names + WordWatcher.new(text).tag_names,
            Discourse.system_user.guardian,
            category,
          )
      end
      return Set.new if names.empty?

      tags = Tag.where_name(names).to_a
      if tags.map { |tag| tag.name.downcase }.uniq.size < names.map(&:downcase).uniq.size
        raise_prospective_refusal!(error)
      end

      tags.map { |tag| tag.target_tag_id || tag.id }.uniq.to_set
    end

    # The tag names one tagging step stores: the names saving keeps, with
    # synonyms replaced by their targets, plus the parent tags they require.
    def saved_tag_names(names, guardian, category)
      names = Array(DiscourseTagging.tags_for_saving(names, guardian))
      return names if names.empty?

      targets =
        Tag
          .where_name(names)
          .joins(:target_tag)
          .includes(:target_tag)
          .to_h { |tag| [tag.name, tag.target_tag.name] }
      names = names.map { |name| targets.fetch(name, name) }

      tag_ids = Tag.where_name(names).pluck(:id)
      parent_tags_map = DiscourseTagging.parent_tags_map(tag_ids, category)
      parent_ids = DiscourseTagging.missing_parent_tag_ids(tag_ids, parent_tags_map)
      names + Tag.where(id: parent_ids).pluck(:name)
    end

    # Refuses a write whose stored topic would be restricted. The default
    # error is the one a missing category gets; writes that have no missing
    # target to mirror pass the policy refusal instead.
    #
    # @param tag_names [Array<String>, nil]
    # @param category_id [Integer, nil]
    # @param text [String, nil] The title and raw of a topic being created.
    # @param private_message [Boolean]
    # @param error [String] The `mcp.errors` key of the refusal.
    # @param guardian [Guardian, nil] Whose permissions the save uses; the caller's by default.
    # @returns [void]
    def ensure_prospective_topic!(
      request_context,
      tag_names:,
      category_id:,
      text: nil,
      private_message: false,
      error: "content_policy_output_blocked",
      guardian: nil
    )
      policy = request_context.content_policy
      return if !policy.active?

      tag_ids =
        prospective_tag_ids!(request_context, tag_names:, category_id:, text:, error:, guardian:)
      if !policy.allows_prospective_topic?(category_id:, tag_ids:, private_message:)
        raise_prospective_refusal!(error)
      end
    end

    # Tags may be given as names or, in queued payloads, as `{ id:, name: }`
    # hashes, which saving reads by id first.
    def tag_param_names(tag_params)
      tag_params = Array(tag_params)
      return tag_params.map(&:to_s) if tag_params.empty? || !tag_params.first.is_a?(Hash)

      tag_params = tag_params.map(&:with_indifferent_access)
      ids = tag_params.filter_map { |tag| tag[:id]&.to_i }
      tag_params.filter_map { |tag| tag[:id].blank? && tag[:name].presence } +
        Tag.where(id: ids).pluck(:name)
    end

    def raise_prospective_refusal!(error = "content_policy_output_blocked")
      raise ToolError, I18n.t("mcp.errors.#{error}")
    end

    # While any content rule is active, a tool may only point at uploads
    # granted to the caller's authorization, because any other upload may
    # belong to restricted content. Unknown and ungranted uploads get the same
    # error.
    #
    # @param upload_ids [Array<Object>] Upload ids from the arguments.
    # @param upload_urls [Array<Object>] Upload URLs from the arguments.
    def ensure_granted_uploads!(request_context, upload_ids: [], upload_urls: [])
      return if !request_context.content_policy.active?

      uploads =
        upload_ids.compact_blank.map { |id| Upload.find_by(id: id.to_i) } +
          upload_urls.compact_blank.map { |url| Upload.get_from_url(url.to_s) }
      uploads.each { |upload| request_context.authored_text.ensure_granted_upload!(upload) }
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
