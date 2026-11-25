# frozen_string_literal: true

module DiscourseMcp
  module Tools
    module ModerationSupport
      PER_PAGE = 10
      STATUSES = %w[pending approved rejected ignored deleted reviewed all].freeze
      FILTER_KEYS = %w[
        priority
        username
        reviewed_by
        claimed_by
        type
        sort_order
        flagged_by
        score_type
      ].freeze
      CORE_ADDITIONAL_FIELDS = {
        "revise_and_reject_post" => %w[revise_reason revise_feedback revise_custom_reason],
      }.freeze

      module_function

      def ensure_queue_access!(guardian)
        guardian.ensure_can_see_review_queue!
      end

      def without_private_messages(scope, request_context)
        scope = allowed_by_policy(scope, request_context.content_policy)
        return scope if request_context.has_scopes?(Scopes::PRIVATE_MESSAGES_READ)

        private_message_topic_ids =
          Topic.unscoped.where(archetype: Archetype.private_message).select(:id)
        scope.where(topic_id: nil).or(scope.where.not(topic_id: private_message_topic_ids))
      end

      # Reviewable types without a topic that the policy can judge: users, and
      # queued posts by the category and tags they'd be created with.
      TOPICLESS_TYPES = %w[ReviewableUser ReviewableQueuedPost].freeze

      # While a rule is active, a reviewable with a topic follows that topic. A
      # queued post without one is judged by its category and the tags in its
      # payload; a personal message without a topic, by its tags while personal
      # messages are allowed. Other reviewable types without a topic can't be
      # judged, so they're left out.
      def allowed_by_policy(scope, policy)
        condition = policy.topic_condition("mcp_reviewable_topics")
        return scope if condition.nil?

        restricted_categories = policy.restricted_category_ids.to_a.presence || [-1]
        restricted_tags = policy.restricted_tag_names.map(&:downcase).presence || [""]
        scope.where(
          <<~SQL.squish,
            (
              reviewables.topic_id IS NOT NULL AND EXISTS (
                SELECT 1 FROM topics mcp_reviewable_topics
                WHERE mcp_reviewable_topics.id = reviewables.topic_id AND #{condition}
              )
            ) OR (
              reviewables.topic_id IS NULL AND (
                reviewables.type = 'ReviewableUser' OR (
                  reviewables.type = 'ReviewableQueuedPost'
                  AND (
                    (
                      COALESCE(reviewables.payload->>'archetype', '') <> :private_message
                      AND COALESCE(reviewables.category_id, :uncategorized) NOT IN (:restricted_categories)
                    ) OR (
                      reviewables.payload->>'archetype' = :private_message AND NOT :private_messages_denied
                    )
                  )
                  AND NOT EXISTS (
                    SELECT 1
                    FROM jsonb_array_elements_text(
                      CASE jsonb_typeof(reviewables.payload::jsonb->'tags')
                      WHEN 'array' THEN reviewables.payload::jsonb->'tags'
                      ELSE '[]'::jsonb END
                    ) AS queued_tags(name)
                    WHERE LOWER(queued_tags.name) IN (:restricted_tags)
                  )
                )
              )
            )
          SQL
          private_message: Archetype.private_message,
          uncategorized: SiteSetting.uncategorized_category_id,
          restricted_categories:,
          restricted_tags:,
          private_messages_denied: policy.denies_all?(ContentPolicy::PRIVATE_MESSAGES),
        )
      end

      # Conversation posts are side-loaded on their own, keyed by post id.
      def without_restricted_conversation_posts(side_loads, policy)
        posts = side_loads[:conversation_posts]
        return side_loads if !posts.is_a?(Array) || posts.empty?

        topic_ids =
          Post.with_deleted.where(id: posts.map { |post| post[:id] }).pluck(:id, :topic_id)
        allowed = policy.allowed_topic_ids(topic_ids.map(&:last))
        allowed_post_ids = topic_ids.filter_map { |id, topic_id| id if allowed.include?(topic_id) }
        side_loads.merge(
          conversation_posts: posts.select { |post| allowed_post_ids.include?(post[:id]) },
        )
      end

      # A flag's conversation lives in its own topic, which can be restricted
      # while the flagged post isn't. Such a conversation is left out, whether
      # it's embedded, side-loaded or referenced by id. A conversation's id is
      # its topic's id.
      def without_restricted_conversations(value, policy)
        case value
        when Array
          value.map { |item| without_restricted_conversations(item, policy) }
        when Hash
          value.each_with_object({}) do |(key, item), result|
            case key
            when :reviewable_conversation
              next if item.is_a?(Hash) && !policy.allows_topic_id?(item[:id])
            when :reviewable_conversations
              if item.is_a?(Array)
                item =
                  item.select { |entry| !entry.is_a?(Hash) || policy.allows_topic_id?(entry[:id]) }
              end
            when :reviewable_conversation_id
              item = nil if item.present? && !policy.allows_topic_id?(item)
            end
            result[key] = without_restricted_conversations(item, policy)
          end
        else
          value
        end
      end

      def ensure_private_message_scope!(reviewable, request_context, access:)
        topic = reviewable.topic || Topic.unscoped.find_by(id: reviewable.topic_id)
        return if topic.blank?

        ToolHelpers.ensure_topic_access!(
          topic,
          request_context,
          access:,
          not_found: I18n.t("mcp.errors.reviewable_not_found"),
        )
      end

      def with_deleted_content(guardian, &block)
        return yield unless guardian.is_staff?

        Post.unscoped { Topic.unscoped { PostAction.unscoped(&block) } }
      end

      def list_filters(arguments)
        status = arguments.fetch("status", "pending")
        if !STATUSES.include?(status)
          raise ToolError, I18n.t("mcp.errors.invalid_reviewable_status")
        end

        type = arguments["type"]
        if type.present? && !Reviewable.valid_filter_type?(type)
          raise ToolError, I18n.t("mcp.errors.invalid_reviewable_type")
        end

        filters = {
          status: status.to_sym,
          topic_id: arguments["topic_id"],
          category_id: arguments["category_id"],
          from_date: parse_time(arguments["from_date"]),
          to_date: parse_time(arguments["to_date"]),
        }
        FILTER_KEYS.each { |key| filters[key.to_sym] = arguments[key] }
        filters.compact
      end

      def parse_time(value)
        return if value.blank?

        Time.zone.iso8601(value)
      rescue ArgumentError
        raise ToolError, I18n.t("mcp.errors.invalid_date")
      end

      def serialize_reviewables(reviewables, request_context)
        guardian = request_context.guardian
        claimed_topics =
          ReviewableClaimedTopic.claimed_hash(reviewables.map(&:topic_id).compact.uniq)
        Reviewable.preload_author_penalties(reviewables)
        side_loads = {}
        serialized =
          reviewables.map do |reviewable|
            reviewable
              .serializer
              .new(
                reviewable,
                root: nil,
                hash: side_loads,
                scope: guardian,
                claimed_topics:,
                include_private_conversations:
                  request_context.has_scopes?(Scopes::PRIVATE_MESSAGES_READ),
              )
              .as_json
          end

        side_loads.each_value { |value| value.uniq! if value.is_a?(Array) }
        serialized = serialized.map(&:deep_symbolize_keys)
        side_loads = side_loads.deep_symbolize_keys
        policy = request_context.content_policy
        if policy.active?
          serialized =
            without_restricted_conversations(without_content_counters(serialized), policy)
          side_loads =
            without_restricted_conversations(without_content_counters(side_loads), policy)
          side_loads = without_restricted_conversation_posts(side_loads, policy)
        end
        [bounded(serialized), bounded(side_loads)]
      end

      # Per-user counters in reviewable payloads that restricted content feeds:
      # flag outcomes count flags on every post, personal messages included.
      CONTENT_COUNTER_KEYS = %i[
        agree_stats
        flags_agreed
        flags_disagreed
        flags_ignored
        post_count
        topic_count
        rejected_posts_count
      ].freeze

      def without_content_counters(value)
        case value
        when Array
          value.map { |item| without_content_counters(item) }
        when Hash
          value
            .except(*CONTENT_COUNTER_KEYS)
            .transform_values { |item| without_content_counters(item) }
        else
          value
        end
      end

      def serialize_reviewable(reviewable, request_context)
        reviewables, side_loads = serialize_reviewables([reviewable], request_context)
        { reviewable: reviewables.first, **side_loads }
      end

      def bounded(value)
        case value
        when String
          value.first(ToolHelpers::MAX_READ_LENGTH)
        when Array
          value.first(100).map { |item| bounded(item) }
        when Hash
          value.to_h { |key, item| [key, bounded(item)] }
        else
          value
        end
      end

      def find_reviewable!(reviewable_id, request_context)
        scope =
          allowed_by_policy(
            Reviewable.viewable_by(request_context.user),
            request_context.content_policy,
          )
        scope.find_by(id: reviewable_id) or
          raise ToolError, I18n.t("mcp.errors.reviewable_not_found")
      end

      # While any content rule is active, agents can't delete accounts, because
      # that deletes everything the user wrote, restricted content included. Nor
      # can they pass extra fields, which reach the user as a personal message.
      # Actions that publish a queued post or show a hidden or deleted post
      # again, which cooks the post's stored raw.
      PUBLISHING_ACTIONS = %w[approve_post approve_post_closed revise_and_reject_post].freeze
      RESTORING_ACTIONS = %w[
        approve_and_restore
        approve_and_unhide
        agree_and_restore
        disagree
        disagree_and_restore
      ].freeze

      def ensure_action_respects_content_policy!(
        reviewable,
        action,
        additional_fields,
        request_context
      )
        return if !request_context.content_policy.active?

        server_action = action.server_action.to_s
        deletes_account =
          server_action.start_with?("delete_user") || server_action == "delete_and_block_user"
        if deletes_account || additional_fields.present?
          raise ToolError, I18n.t("mcp.errors.content_policy_blocked")
        end

        request_context.authored_text.ensure_allowed!(*stored_texts(reviewable, server_action))
        ensure_prospective_queued_topic!(reviewable, server_action, request_context)
      end

      # Approving a queued new topic creates it with the payload's category and
      # tags plus the parent and watched-word tags they add, so the topic it
      # would become must be allowed.
      def ensure_prospective_queued_topic!(reviewable, server_action, request_context)
        return if !PUBLISHING_ACTIONS.include?(server_action) || server_action.start_with?("revise")
        return if !reviewable.is_a?(ReviewableQueuedPost) || reviewable.topic_id.present?

        # Approval creates the topic from these options, so the check reads them
        # the same way: hash tags by name, the reviewable's category first.
        options = reviewable.create_options
        ToolHelpers.ensure_prospective_topic!(
          request_context,
          tag_names: options[:tags],
          category_id: options[:category],
          text: "#{options[:title]} #{options[:raw]}",
          private_message: options[:archetype] == Archetype.private_message,
          error: "content_policy_blocked",
          # Approval saves with the reviewer's permissions only when they are
          # staff, and with the queued author's otherwise.
          guardian:
            (
              if request_context.user.staff?
                request_context.guardian
              else
                reviewable.target_created_by&.guardian
              end
            ),
        )
      end

      # The stored text that an action would cook, which must pass the same
      # check as agent text.
      def stored_texts(reviewable, server_action)
        if PUBLISHING_ACTIONS.include?(server_action) && reviewable.is_a?(ReviewableQueuedPost)
          [reviewable.payload["title"], reviewable.payload["raw"]].compact
        elsif RESTORING_ACTIONS.include?(server_action) && reviewable.target_type == "Post"
          [Post.with_deleted.find_by(id: reviewable.target_id)&.raw].compact
        else
          []
        end
      end

      def find_visible_post!(post_id, guardian)
        post = Post.with_deleted.find_by(id: post_id)
        topic = Topic.with_deleted.find_by(id: post&.topic_id)
        post.association(:topic).target = topic if post && topic

        deleted = post&.deleted_at.present? || topic&.deleted_at.present?
        if post.blank? || topic.blank? || (deleted && !guardian.can_moderate_topic?(topic)) ||
             !guardian.can_see?(post)
          raise ToolError, I18n.t("mcp.errors.post_not_found")
        end

        post
      end

      def available_actions(reviewable, guardian)
        reviewable.actions_for(guardian).bundles.flat_map(&:actions).uniq
      end

      def find_action!(reviewable, guardian, action_id)
        actions = available_actions(reviewable, guardian)
        action = actions.find { |candidate| candidate.id.to_s == action_id }
        action ||= actions.find { |candidate| candidate.server_action.to_s == action_id }
        action or raise ToolError, I18n.t("mcp.errors.reviewable_action_unavailable")
      end

      def action_arguments(reviewable, action, supplied)
        server_action = action.server_action.to_s
        allowed = Array(CORE_ADDITIONAL_FIELDS[server_action])
        allowed += %w[reject_reason send_email] if reviewable.is_a?(ReviewableUser)
        allowed +=
          DiscoursePluginRegistry
            .reviewable_params
            .select { |entry| reviewable.type == entry[:type].to_s.classify }
            .map { |entry| entry[:param].to_s }
        allowed.uniq!

        disallowed = supplied.keys - allowed
        if disallowed.present?
          raise ToolError,
                I18n.t("mcp.errors.reviewable_fields_unavailable", fields: disallowed.join(", "))
        end
        if action.require_reject_reason && supplied["reject_reason"].blank?
          raise ToolError, I18n.t("mcp.errors.reviewable_reject_reason_required")
        end

        result = supplied.symbolize_keys
        result[:send_email] = true if reviewable.is_a?(ReviewableUser) && !result.key?(:send_email)
        result
      end

      def ensure_claim_allows_action!(reviewable, user)
        return if SiteSetting.reviewable_claiming == "disabled" || reviewable.topic_id.blank?

        claimed_by_id = ReviewableClaimedTopic.where(topic_id: reviewable.topic_id).pick(:user_id)
        if SiteSetting.reviewable_claiming == "required" && claimed_by_id.blank?
          raise ToolError, I18n.t("reviewables.must_claim")
        end
        if claimed_by_id && claimed_by_id != user.id
          raise ToolError, I18n.t("reviewables.user_claimed")
        end
      end
    end

    class GetReviewQueueCount
      REQUIRED_SCOPES = [Scopes::MODERATION_READ].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
          count: OutputSchema::INTEGER,
          unit: OutputSchema::STRING,
          status: OutputSchema::STRING,
          scope: OutputSchema::STRING,
        )

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        ModerationSupport.ensure_queue_access!(guardian)
        scope = Reviewable.list_for(request_context.user)
        scope = ModerationSupport.without_private_messages(scope, request_context)
        ToolHelpers.text_and_structured(
          count: scope.count,
          unit: "pending_reviewable_queue_items",
          status: "pending",
          scope: "visible_to_authenticated_user",
        )
      end
    end

    class ListReviewables
      REQUIRED_SCOPES = [Scopes::MODERATION_READ].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA = OutputSchema::OBJECT

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        ModerationSupport.ensure_queue_access!(guardian)
        offset = arguments.fetch("offset", 0)
        filters = ModerationSupport.list_filters(arguments)

        ModerationSupport.with_deleted_content(guardian) do
          query = Reviewable.list_for(request_context.user, **filters)
          query = ModerationSupport.without_private_messages(query, request_context)
          total = query.count
          reviewables = query.limit(ModerationSupport::PER_PAGE).offset(offset).to_a
          rows, side_loads = ModerationSupport.serialize_reviewables(reviewables, request_context)
          has_more = offset + rows.length < total
          ToolHelpers.text_and_structured(
            reviewables: rows,
            **side_loads,
            meta: {
              offset:,
              per_page: ModerationSupport::PER_PAGE,
              returned: rows.length,
              total:,
              has_more:,
              next_offset: has_more ? offset + ModerationSupport::PER_PAGE : nil,
              status: filters[:status].to_s,
              scope: "visible_to_authenticated_user",
            },
          )
        end
      end
    end

    class ListReviewableTopics
      REQUIRED_SCOPES = [Scopes::MODERATION_READ].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(topics: OutputSchema::OBJECT_ARRAY, meta: OutputSchema::OBJECT)

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        ModerationSupport.ensure_queue_access!(guardian)
        offset = arguments.fetch("offset", 0)
        limit = arguments.fetch("limit", 100)
        reviewable_scope =
          ModerationSupport
            .without_private_messages(
              Reviewable.viewable_by(request_context.user, preload: false),
              request_context,
            )
            .pending
            .where("score >= ?", Reviewable.min_score_for_priority)
        visible_topic_ids =
          reviewable_scope.reorder(nil).where.not(topic_id: nil).select(:topic_id).distinct
        topic_scope = Topic.where(id: visible_topic_ids).order(reviewable_score: :desc, id: :desc)
        total = topic_scope.count
        topics = topic_scope.offset(offset).limit(limit).to_a
        topic_ids = topics.map(&:id)
        serialized_stats = topic_ids.index_with { { count: 0, unique_users: 0 } }
        if topic_ids.present?
          visible_reviewable_ids =
            reviewable_scope.reorder(nil).where(topic_id: topic_ids).select(:id)
          ReviewableScore
            .joins(:reviewable)
            .where(reviewable_id: visible_reviewable_ids)
            .group("reviewables.topic_id")
            .pluck(
              "reviewables.topic_id",
              Arel.sql("COUNT(*)"),
              Arel.sql("COUNT(DISTINCT reviewable_scores.user_id)"),
            )
            .each do |topic_id, count, unique_users|
              serialized_stats[topic_id] = { count:, unique_users: }
            end
        end
        claimed_topics = ReviewableClaimedTopic.claimed_hash(topic_ids)
        serialized_topics =
          topics.map do |topic|
            ReviewableTopicSerializer.new(
              topic,
              root: false,
              scope: guardian,
              stats: serialized_stats,
              claimed_topics:,
            ).as_json
          end
        has_more = offset + serialized_topics.length < total

        ToolHelpers.text_and_structured(
          topics: ModerationSupport.bounded(serialized_topics),
          meta: {
            exhaustive: false,
            offset:,
            limit:,
            returned: serialized_topics.length,
            total:,
            has_more:,
            next_offset: has_more ? offset + serialized_topics.length : nil,
            scope: "pending topics at or above the review priority threshold",
          },
        )
      end
    end

    class GetReviewable
      REQUIRED_SCOPES = [Scopes::MODERATION_READ].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA = OutputSchema::OBJECT

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        ModerationSupport.ensure_queue_access!(guardian)
        ModerationSupport.with_deleted_content(guardian) do
          reviewable =
            ModerationSupport.find_reviewable!(arguments.fetch("reviewable_id"), request_context)
          ModerationSupport.ensure_private_message_scope!(
            reviewable,
            request_context,
            access: :read,
          )
          result = ModerationSupport.serialize_reviewable(reviewable, request_context)
          if arguments["include_explanation"]
            # Decimal columns would serialize as strings.
            explanation =
              reviewable.explain_score.map do |row|
                row.to_h.symbolize_keys.transform_values do |value|
                  value.is_a?(BigDecimal) ? value.to_f : value
                end
              end
            if request_context.content_policy.active?
              explanation = ModerationSupport.without_content_counters(explanation)
            end
            result[:explanation] = explanation
          end
          ToolHelpers.text_and_structured(ModerationSupport.bounded(result))
        end
      end
    end

    class GetUserModerationSummary
      REQUIRED_SCOPES = [Scopes::MODERATION_READ].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      # Counters derived from what the user wrote, flagged or was warned about
      # (warnings are personal messages), which restricted content feeds.
      CONTENT_COUNTERS = %i[
        deleted_posts
        flags_received
        flags_given
        warnings_received
        rejected_posts
      ].freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
          optional: CONTENT_COUNTERS.map(&:to_s),
          username: OutputSchema::STRING,
          deleted_posts: OutputSchema::INTEGER,
          flags_received: OutputSchema::INTEGER,
          flags_given: OutputSchema::INTEGER,
          silencings: OutputSchema::INTEGER,
          suspensions: OutputSchema::INTEGER,
          warnings_received: OutputSchema::INTEGER,
          rejected_posts: OutputSchema::INTEGER,
        )

      def self.call(arguments:, request_context:)
        user = User.find_by_username(arguments.fetch("username"))
        raise ToolError, I18n.t("mcp.errors.user_not_found") if user.blank?

        request_context.guardian.ensure_can_see_staff_info!(user)
        result = {
          username: user.username,
          deleted_posts: user.number_of_deleted_posts,
          flags_received: user.number_of_flags,
          flags_given: user.number_of_flags_given,
          silencings: user.number_of_silencings,
          suspensions: user.number_of_suspensions,
          warnings_received: user.warnings_received_count,
          rejected_posts: user.number_of_rejected_posts,
        }
        result = result.except(*CONTENT_COUNTERS) if request_context.content_policy.active?
        ToolHelpers.text_and_structured(result)
      end
    end

    class GetPostRevision
      REQUIRED_SCOPES = [Scopes::MODERATION_READ].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA = OutputSchema::OBJECT

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        ModerationSupport.ensure_queue_access!(guardian)
        post = ModerationSupport.find_visible_post!(arguments.fetch("post_id"), guardian)
        ToolHelpers.ensure_topic_access!(
          post.topic,
          request_context,
          access: :read,
          not_found: I18n.t("mcp.errors.post_not_found"),
        )

        finder = PostRevision.where(post_id: post.id)
        finder = finder.where(hidden: false) if !guardian.can_view_hidden_post_revisions?
        requested_revision = arguments.fetch("revision", "latest")
        post_revision =
          if requested_revision == "latest"
            finder.order(:number).last
          else
            finder.find_by(number: requested_revision)
          end
        raise ToolError, I18n.t("mcp.errors.post_revision_not_found") if post_revision.blank?

        post_revision.post = post
        guardian.ensure_can_see!(post_revision)
        result =
          PostRevisionSerializer
            .new(post_revision, root: false, scope: guardian)
            .as_json
            .deep_symbolize_keys
        result = redact_topic_changes(result, request_context.content_policy)
        ToolHelpers.text_and_structured(ModerationSupport.bounded(result))
      end

      # A revision can record a move from or to a restricted category, or a
      # restricted tag added or removed. Those sides of the diff are redacted.
      def self.redact_topic_changes(result, policy)
        return result if !policy.restricts_forum?

        if (changes = result[:category_id_changes]).is_a?(Hash)
          result[:category_id_changes] = changes.transform_values do |id|
            policy.redact_category_id(id)
          end
        end
        if (changes = result[:tags_changes]).is_a?(Hash)
          result[:tags_changes] = changes.transform_values do |names|
            Array(names).select { |name| policy.allows_tag?(name) }
          end
        end
        result
      end
    end

    class PerformReviewableAction
      REQUIRED_SCOPES = [Scopes::MODERATION_WRITE].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA = OutputSchema::OBJECT

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        ModerationSupport.ensure_queue_access!(guardian)
        if arguments["confirm"] != true
          raise ToolError, I18n.t("mcp.errors.reviewable_confirmation_required")
        end
        reviewable =
          ModerationSupport.find_reviewable!(arguments.fetch("reviewable_id"), request_context)
        ModerationSupport.ensure_private_message_scope!(reviewable, request_context, access: :read)
        ModerationSupport.ensure_private_message_scope!(reviewable, request_context, access: :write)
        ModerationSupport.ensure_claim_allows_action!(reviewable, request_context.user)
        action = ModerationSupport.find_action!(reviewable, guardian, arguments.fetch("action_id"))
        if arguments.key?("expected_version") && arguments["expected_version"] != reviewable.version
          raise ToolError, I18n.t("mcp.errors.reviewable_conflict")
        end
        additional_fields = arguments.fetch("additional_fields", {})
        ModerationSupport.ensure_action_respects_content_policy!(
          reviewable,
          action,
          additional_fields,
          request_context,
        )
        action_arguments =
          ModerationSupport.action_arguments(reviewable, action, additional_fields).merge(
            version: reviewable.version,
            guardian:,
          )

        result =
          reviewable.perform(request_context.user, action.server_action.to_sym, action_arguments)
        if !result.success?
          raise ToolError,
                result.errors&.full_messages&.join(", ").presence ||
                  I18n.t("mcp.errors.reviewable_action_failed")
        end

        serialized =
          ReviewablePerformResultSerializer
            .new(result, root: false, scope: guardian)
            .as_json
            .deep_symbolize_keys
        # The queue counts include reviewables the policy hides.
        if request_context.content_policy.active?
          serialized = serialized.except(:reviewable_count, :unseen_reviewable_count)
        end
        ToolHelpers.text_and_structured(
          ModerationSupport
            .bounded(serialized)
            .deep_symbolize_keys
            .merge(reviewable_id: reviewable.id),
        )
      rescue Reviewable::InvalidAction
        raise ToolError, I18n.t("mcp.errors.reviewable_action_unavailable")
      rescue Reviewable::UpdateConflict
        raise ToolError, I18n.t("mcp.errors.reviewable_conflict")
      end
    end
  end
end
