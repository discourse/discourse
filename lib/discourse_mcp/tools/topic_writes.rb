# frozen_string_literal: true

module DiscourseMcp
  module Tools
    class SetTopicClosed
      REQUIRED_SCOPES = [Scopes::MODERATION_WRITE].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
          topic_id: OutputSchema::INTEGER,
          closed: OutputSchema::BOOLEAN,
          archived: OutputSchema::BOOLEAN,
        )

      def self.call(arguments:, request_context:)
        topic = Topic.find_by(id: arguments.fetch("topic_id"))
        guardian = request_context.guardian
        unless topic && guardian.can_see?(topic)
          raise ToolError, I18n.t("mcp.errors.topic_not_found")
        end
        ToolHelpers.ensure_topic_access!(
          topic,
          request_context,
          access: :write,
          not_found: I18n.t("mcp.errors.topic_not_found"),
        )
        guardian.ensure_can_close_topic!(topic)
        closed = arguments.fetch("closed")
        raise Discourse::InvalidParameters.new(:closed) if [true, false].exclude?(closed)

        topic.update_status("closed", closed, request_context.user) if topic.closed != closed
        topic.reload
        ToolHelpers.text_and_structured(
          topic_id: topic.id,
          closed: topic.closed,
          archived: topic.archived,
        )
      end
    end

    class SetTopicPin
      REQUIRED_SCOPES = [Scopes::MODERATION_WRITE].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
          topic_id: OutputSchema::INTEGER,
          pinned: OutputSchema::BOOLEAN,
          pinned_globally: OutputSchema::BOOLEAN,
          pinned_until: OutputSchema::STRING_OR_NULL,
        )

      def self.call(arguments:, request_context:)
        topic = Topic.find_by(id: arguments.fetch("topic_id"))
        guardian = request_context.guardian
        unless topic && guardian.can_see?(topic)
          raise ToolError, I18n.t("mcp.errors.topic_not_found")
        end
        ToolHelpers.ensure_topic_access!(
          topic,
          request_context,
          access: :write,
          not_found: I18n.t("mcp.errors.topic_not_found"),
        )
        mode = arguments.fetch("mode")
        raise Discourse::InvalidParameters.new(:mode) if %w[category global unpin].exclude?(mode)
        if mode == "global"
          guardian.ensure_can_moderate!(topic)
        else
          guardian.ensure_can_pin_unpin_topic!(topic)
        end

        topic.update_status(
          mode == "global" ? "pinned_globally" : "pinned",
          mode != "unpin",
          request_context.user,
        )
        topic.reload
        ToolHelpers.text_and_structured(
          topic_id: topic.id,
          pinned: topic.pinned_at.present?,
          pinned_globally: topic.pinned_globally,
          pinned_until: topic.pinned_until&.iso8601,
        )
      end
    end

    class CreateTopic
      REQUIRED_SCOPES = [Scopes::CONTENT_WRITE].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :untouched,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
          queued: OutputSchema::BOOLEAN,
          id: OutputSchema::INTEGER_OR_NULL,
          topic_id: OutputSchema::INTEGER_OR_NULL,
          slug: OutputSchema::STRING_OR_NULL,
          title: OutputSchema::STRING,
          username: OutputSchema::STRING,
          requested_author: OutputSchema::STRING_OR_NULL,
          author_applied: OutputSchema::BOOLEAN_OR_NULL,
        )

      def self.call(arguments:, request_context:)
        user = request_context.user
        ToolHelpers.ensure_current_author!(arguments, user)
        category_id = arguments["category_id"]
        if category_id
          request_context.guardian.ensure_can_create!(Topic)
          # NewPostManager raises ActiveRecord::RecordNotFound for a missing category,
          # and a restricted category answers like a missing one.
          if !Category.exists?(id: category_id) ||
               !request_context.content_policy.allows_category_id?(category_id)
            raise Discourse::InvalidParameters.new(:category_id)
          end
        end
        submitted_title = arguments.fetch("title")
        ToolHelpers.ensure_prospective_topic!(
          request_context,
          tag_names: arguments["tags"],
          category_id:,
          text: "#{submitted_title} #{arguments.fetch("raw")}",
        )
        submission =
          ToolHelpers.submit_post!(
            user,
            title: submitted_title,
            raw: arguments.fetch("raw"),
            category: category_id,
            tags: Array(arguments["tags"]),
          )
        ToolHelpers.text_and_structured(
          **topic_fields(submission, submitted_title, request_context.content_policy),
          **ToolHelpers.author_fields(arguments, user),
        )
      end

      # Server-side rules, such as handlers that retag a new topic, can leave
      # the topic restricted. The agent wrote it, but gets nothing that locates it.
      def self.topic_fields(submission, submitted_title, policy)
        if ToolHelpers.queued?(submission)
          { queued: true, id: nil, topic_id: nil, slug: nil, title: submitted_title }
        else
          post = submission.post
          topic = post.topic.reload
          if policy.allows_topic?(topic)
            { queued: false, id: post.id, topic_id: topic.id, slug: topic.slug, title: topic.title }
          else
            { queued: false, id: nil, topic_id: nil, slug: nil, title: submitted_title }
          end
        end
      end
      private_class_method :topic_fields
    end

    class ReplyTopic
      REQUIRED_SCOPES = [Scopes::CONTENT_WRITE].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
          queued: OutputSchema::BOOLEAN,
          id: OutputSchema::INTEGER_OR_NULL,
          topic_id: OutputSchema::INTEGER,
          post_number: OutputSchema::INTEGER_OR_NULL,
          username: OutputSchema::STRING,
          requested_author: OutputSchema::STRING_OR_NULL,
          author_applied: OutputSchema::BOOLEAN_OR_NULL,
        )

      def self.call(arguments:, request_context:)
        user = request_context.user
        ToolHelpers.ensure_current_author!(arguments, user)
        topic = Topic.find_by(id: arguments.fetch("topic_id"))
        if topic.blank? || !request_context.guardian.can_see?(topic)
          raise ToolError, I18n.t("mcp.errors.topic_not_found")
        end
        ToolHelpers.ensure_topic_access!(
          topic,
          request_context,
          access: :write,
          not_found: I18n.t("mcp.errors.topic_not_found"),
        )
        submission =
          ToolHelpers.submit_post!(
            user,
            topic_id: topic.id,
            raw: arguments.fetch("raw"),
            reply_to_post_number: arguments["reply_to_post_number"],
          )
        ToolHelpers.text_and_structured(
          **reply_fields(submission),
          topic_id: topic.id,
          **ToolHelpers.author_fields(arguments, user),
        )
      end

      def self.reply_fields(submission)
        if ToolHelpers.queued?(submission)
          { queued: true, id: nil, post_number: nil }
        else
          post = submission.post
          { queued: false, id: post.id, post_number: post.post_number }
        end
      end
      private_class_method :reply_fields
    end

    class EditPost
      REQUIRED_SCOPES = [Scopes::CONTENT_WRITE].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
          id: OutputSchema::INTEGER,
          topic_id: OutputSchema::INTEGER,
          post_number: OutputSchema::INTEGER,
          raw: OutputSchema::STRING,
          updated_at: OutputSchema::STRING,
          edit_reason: OutputSchema::STRING_OR_NULL,
        )

      def self.call(arguments:, request_context:)
        post = Post.find_by(id: arguments.fetch("post_id").to_i)
        if post.blank? || !request_context.guardian.can_edit_post?(post)
          raise DiscourseMcp::ToolError, I18n.t("mcp.errors.post_not_found")
        end

        ToolHelpers.ensure_topic_access!(
          post.topic,
          request_context,
          access: :write,
          not_found: I18n.t("mcp.errors.post_not_found"),
        )
        # Raw HTML and email posts don't use the renderer that agent text is
        # checked with, so agents can't edit them while a rule is active.
        if request_context.content_policy.active? && post.cook_method != Post.cook_methods[:regular]
          raise ToolError, I18n.t("mcp.errors.content_policy_blocked")
        end
        fields = { raw: arguments.fetch("raw") }
        fields[:edit_reason] = arguments["edit_reason"] if arguments["edit_reason"].present?
        success = PostRevisor.new(post, post.topic).revise!(request_context.user, fields)
        raise ToolError, post.errors.full_messages.join(", ") if !success
        post.reload
        ToolHelpers.text_and_structured(
          id: post.id,
          topic_id: post.topic_id,
          post_number: post.post_number,
          raw: post.raw,
          updated_at: post.updated_at.iso8601,
          edit_reason: post.edit_reason,
        )
      end
    end

    class UpdateTopic
      REQUIRED_SCOPES = [Scopes::CONTENT_WRITE].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      MUTABLE_FIELDS = %w[title category_id tags featured_link].freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
          success: OutputSchema::BOOLEAN,
          topic_id: OutputSchema::INTEGER,
          updated_fields: OutputSchema::STRING_ARRAY,
          topic: OutputSchema::OBJECT,
        )

      def self.call(arguments:, request_context:)
        topic = Topic.find_by(id: arguments.fetch("topic_id"))
        raise ToolError, I18n.t("mcp.errors.topic_not_found") if topic.blank?

        guardian = request_context.guardian
        ToolHelpers.ensure_topic_access!(
          topic,
          request_context,
          access: :write,
          not_found: I18n.t("mcp.errors.topic_not_found"),
        )
        guardian.ensure_can_edit!(topic)
        verify_original_values!(topic, arguments, guardian)
        changes = requested_changes(topic, arguments, guardian)
        shared_draft = topic.shared_draft
        destination_category_id = changes.delete("category_id") if shared_draft
        updated_fields = changes.keys
        updated_fields << "category_id" if destination_category_id
        raise ToolError, I18n.t("mcp.errors.topic_update_required") if updated_fields.empty?

        policy = request_context.content_policy
        if !policy.allows_category_id?(changes["category_id"]) ||
             !policy.allows_category_id?(destination_category_id)
          raise ToolError, I18n.t("category.errors.not_found")
        end
        ensure_safe_update!(topic, changes, request_context) if policy.active?

        Topic.transaction do
          shared_draft.update!(category_id: destination_category_id) if destination_category_id

          if changes.present?
            category_changed = changes.key?("category_id")
            success =
              PostRevisor.new(topic.first_post, topic).revise!(
                request_context.user,
                changes.symbolize_keys,
                validate_post: false,
              )
            if !success
              raise ToolError,
                    TopicCategoryChangeValidator.safe_revision_errors(
                      topic:,
                      guardian:,
                      category_changed:,
                    ).join(", ")
            end
          end

          # Revising can move or retag the topic, so the result is checked as
          # stored. A topic that would become restricted rolls the whole change back.
          topic.reload
          if !policy.allows_topic?(topic)
            raise ToolError, I18n.t("mcp.errors.content_policy_output_blocked")
          end
        end

        topic.reload
        visible_tag_ids = ToolHelpers.visible_tag_ids([topic], guardian)
        ToolHelpers.text_and_structured(
          success: true,
          topic_id: topic.id,
          updated_fields:,
          topic: {
            id: topic.id,
            title: topic.title,
            slug: topic.slug,
            category_id: topic.category_id,
            destination_category_id: topic.shared_draft&.category_id,
            tags: topic.tags.select { |tag| visible_tag_ids.include?(tag.id) }.map(&:name),
            featured_link: topic.featured_link,
          },
        )
      end

      # Revising recooks the first post, so its stored raw must pass the same
      # check as agent text. Moving a topic while secure uploads are on rebakes
      # other posts, which agents can't trigger. The stored topic must also stay
      # allowed with its new category and complete effective tags.
      def self.ensure_safe_update!(topic, changes, request_context)
        request_context.authored_text.ensure_allowed!(topic.first_post&.raw.to_s)
        if changes.key?("category_id") && SiteSetting.secure_uploads?
          raise ToolError, I18n.t("mcp.errors.content_policy_blocked")
        end

        ToolHelpers.ensure_prospective_topic!(
          request_context,
          tag_names: changes.fetch("tags") { topic.tags.map(&:name) },
          category_id: changes["category_id"] || topic.category_id,
          private_message: topic.private_message?,
        )
      end
      private_class_method :ensure_safe_update!

      def self.verify_original_values!(topic, arguments, guardian)
        if arguments.key?("original_title") && arguments["original_title"] != topic.title
          raise ToolError, I18n.t("edit_conflict")
        end
        visible_tag_ids = ToolHelpers.visible_tag_ids([topic], guardian)
        visible_tag_names =
          topic.tags.select { |tag| visible_tag_ids.include?(tag.id) }.map(&:name).sort
        if arguments.key?("original_tags") && arguments["original_tags"].sort != visible_tag_names
          raise ToolError, I18n.t("edit_conflict")
        end
      end
      private_class_method :verify_original_values!

      def self.requested_changes(topic, arguments, guardian)
        changes = arguments.slice(*MUTABLE_FIELDS)
        changes.delete("title") if changes["title"] == topic.title
        current_category_id = topic.shared_draft&.category_id || topic.category_id
        changes.delete("category_id") if changes["category_id"].to_i == current_category_id.to_i
        if changes.key?("tags") && PostRevisor.tag_change_noop?(topic, changes["tags"])
          changes.delete("tags")
        end
        changes.delete("featured_link") if changes["featured_link"] == topic.featured_link

        if changes.key?("category_id")
          category_validation =
            TopicCategoryChangeValidator.call(
              topic:,
              category_id: changes["category_id"],
              guardian:,
              tag_names: changes.fetch("tags", topic.tags.map(&:name)),
              tags_changed: changes.key?("tags"),
            )
          if !category_validation.success?
            raise Discourse::InvalidAccess if category_validation.status == :forbidden

            raise ToolError, category_validation.error
          end
        end
        changes
      end
      private_class_method :requested_changes
    end

    class SetPostDeleted
      REQUIRED_SCOPES = [Scopes::CONTENT_WRITE].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(post_id: OutputSchema::INTEGER, deleted: OutputSchema::BOOLEAN)

      def self.call(arguments:, request_context:)
        posts = arguments.fetch("deleted") ? Post.all : Post.with_deleted
        post = posts.find_by(id: arguments.fetch("post_id").to_i, user_id: request_context.user_id)
        raise DiscourseMcp::ToolError, "Post not found" if post.blank?
        post.topic ||= Topic.with_deleted.find_by(id: post.topic_id)
        ToolHelpers.ensure_topic_access!(
          post.topic,
          request_context,
          access: :write,
          not_found: "Post not found",
        )

        if arguments.fetch("deleted")
          if !request_context.guardian.can_delete_post_or_topic?(post)
            raise Discourse::InvalidAccess
          end
        else
          raise Discourse::InvalidAccess if !request_context.guardian.can_recover_post?(post)
        end

        if arguments.fetch("deleted")
          PostDestroyer.new(request_context.user, post).destroy
        else
          ensure_recoverable_raw!(post, request_context)
          PostDestroyer.new(request_context.user, post).recover
        end
        ToolHelpers.text_and_structured(post_id: post.id, deleted: arguments.fetch("deleted"))
      end

      # Recovering a post recooks it, and recovering one its author deleted
      # restores the raw it had before, so both must pass the agent text check.
      def self.ensure_recoverable_raw!(post, request_context)
        return if !request_context.content_policy.active?

        raws = [post.raw]
        if post.user_deleted?
          raws << post.revisions.order(:number).last&.modifications&.dig("raw", 0)
        end
        request_context.authored_text.ensure_allowed!(*raws.compact)
      end
      private_class_method :ensure_recoverable_raw!
    end
  end
end
