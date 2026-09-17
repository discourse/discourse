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
        return scope if request_context.has_scopes?(Scopes::PRIVATE_MESSAGES_READ)

        private_message_topic_ids =
          Topic.unscoped.where(archetype: Archetype.private_message).select(:id)
        scope.where(topic_id: nil).or(scope.where.not(topic_id: private_message_topic_ids))
      end

      def ensure_private_message_scope!(reviewable, request_context, access:)
        topic = reviewable.topic || Topic.unscoped.find_by(id: reviewable.topic_id)
        return if topic.blank?

        ToolHelpers.ensure_private_message_scope!(topic, request_context, access:)
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

      def serialize_reviewables(reviewables, guardian)
        claimed_topics =
          ReviewableClaimedTopic.claimed_hash(reviewables.map(&:topic_id).compact.uniq)
        Reviewable.preload_author_penalties(reviewables)
        side_loads = {}
        serialized =
          reviewables.map do |reviewable|
            reviewable
              .serializer
              .new(reviewable, root: nil, hash: side_loads, scope: guardian, claimed_topics:)
              .as_json
          end

        side_loads.each_value { |value| value.uniq! if value.is_a?(Array) }
        [bounded(serialized), bounded(side_loads).deep_symbolize_keys]
      end

      def serialize_reviewable(reviewable, guardian)
        reviewables, side_loads = serialize_reviewables([reviewable], guardian)
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

      def find_reviewable!(reviewable_id, user)
        Reviewable.viewable_by(user).find_by(id: reviewable_id) or
          raise ToolError, I18n.t("mcp.errors.reviewable_not_found")
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
          rows, side_loads = ModerationSupport.serialize_reviewables(reviewables, guardian)
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
      OUTPUT_SCHEMA = OutputSchema::OBJECT

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        ModerationSupport.ensure_queue_access!(guardian)
        ModerationSupport.with_deleted_content(guardian) do
          reviewable =
            ModerationSupport.find_reviewable!(
              arguments.fetch("reviewable_id"),
              request_context.user,
            )
          ModerationSupport.ensure_private_message_scope!(
            reviewable,
            request_context,
            access: :read,
          )
          result = ModerationSupport.serialize_reviewable(reviewable, guardian)
          result[:explanation] = reviewable.explain_score if arguments["include_explanation"]
          ToolHelpers.text_and_structured(ModerationSupport.bounded(result))
        end
      end
    end

    class GetUserModerationSummary
      REQUIRED_SCOPES = [Scopes::MODERATION_READ].freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
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
        ToolHelpers.text_and_structured(
          username: user.username,
          deleted_posts: user.number_of_deleted_posts,
          flags_received: user.number_of_flags,
          flags_given: user.number_of_flags_given,
          silencings: user.number_of_silencings,
          suspensions: user.number_of_suspensions,
          warnings_received: user.warnings_received_count,
          rejected_posts: user.number_of_rejected_posts,
        )
      end
    end

    class GetPostRevision
      REQUIRED_SCOPES = [Scopes::MODERATION_READ].freeze
      OUTPUT_SCHEMA = OutputSchema::OBJECT

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        ModerationSupport.ensure_queue_access!(guardian)
        post = ModerationSupport.find_visible_post!(arguments.fetch("post_id"), guardian)
        ToolHelpers.ensure_private_message_scope!(post.topic, request_context, access: :read)

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
        ToolHelpers.text_and_structured(ModerationSupport.bounded(result))
      end
    end

    class PerformReviewableAction
      REQUIRED_SCOPES = [Scopes::MODERATION_WRITE].freeze
      OUTPUT_SCHEMA = OutputSchema::OBJECT

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        ModerationSupport.ensure_queue_access!(guardian)
        if arguments["confirm"] != true
          raise ToolError, I18n.t("mcp.errors.reviewable_confirmation_required")
        end
        reviewable =
          ModerationSupport.find_reviewable!(arguments.fetch("reviewable_id"), request_context.user)
        ModerationSupport.ensure_private_message_scope!(reviewable, request_context, access: :read)
        ModerationSupport.ensure_private_message_scope!(reviewable, request_context, access: :write)
        ModerationSupport.ensure_claim_allows_action!(reviewable, request_context.user)
        action = ModerationSupport.find_action!(reviewable, guardian, arguments.fetch("action_id"))
        if arguments.key?("expected_version") && arguments["expected_version"] != reviewable.version
          raise ToolError, I18n.t("mcp.errors.reviewable_conflict")
        end
        additional_fields = arguments.fetch("additional_fields", {})
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
          ReviewablePerformResultSerializer.new(result, root: false, scope: guardian).as_json
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
