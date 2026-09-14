# frozen_string_literal: true

module DiscourseMcp
  module Tools
    class CreateTopic
      OUTPUT_SCHEMA =
        OutputSchema.object(
          id: OutputSchema::INTEGER,
          topic_id: OutputSchema::INTEGER,
          slug: OutputSchema::STRING,
          title: OutputSchema::STRING,
          username: OutputSchema::STRING,
          requested_author: OutputSchema::STRING_OR_NULL,
          author_applied: OutputSchema::BOOLEAN_OR_NULL,
        )

      def self.call(arguments:, request_context:)
        ToolHelpers.ensure_current_author!(arguments, request_context.user)
        post =
          PostCreator.create!(
            request_context.user,
            title: arguments.fetch("title"),
            raw: arguments.fetch("raw"),
            category: arguments["category_id"],
            tags: Array(arguments["tags"]),
            skip_validations: false,
          )
        requested_author = arguments["author_username"]
        ToolHelpers.text_and_structured(
          id: post.id,
          topic_id: post.topic_id,
          slug: post.topic.slug,
          title: post.topic.title,
          username: post.user.username,
          requested_author:,
          author_applied:
            requested_author.present? ? post.user.username.casecmp?(requested_author) : nil,
        )
      end
    end

    class ReplyTopic
      OUTPUT_SCHEMA =
        OutputSchema.object(
          id: OutputSchema::INTEGER,
          topic_id: OutputSchema::INTEGER,
          post_number: OutputSchema::INTEGER,
          username: OutputSchema::STRING,
          requested_author: OutputSchema::STRING_OR_NULL,
          author_applied: OutputSchema::BOOLEAN_OR_NULL,
        )

      def self.call(arguments:, request_context:)
        ToolHelpers.ensure_current_author!(arguments, request_context.user)
        post =
          PostCreator.create!(
            request_context.user,
            topic_id: arguments.fetch("topic_id"),
            raw: arguments.fetch("raw"),
            reply_to_post_number: arguments["reply_to_post_number"],
          )
        requested_author = arguments["author_username"]
        ToolHelpers.text_and_structured(
          id: post.id,
          topic_id: post.topic_id,
          post_number: post.post_number,
          username: post.user.username,
          requested_author:,
          author_applied:
            requested_author.present? ? post.user.username.casecmp?(requested_author) : nil,
        )
      end
    end

    class EditPost
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
        guardian.ensure_can_edit!(topic)
        verify_original_values!(topic, arguments, guardian)
        changes = requested_changes(topic, arguments, guardian)
        shared_draft = topic.shared_draft
        destination_category_id = changes.delete("category_id") if shared_draft
        updated_fields = changes.keys
        updated_fields << "category_id" if destination_category_id
        raise ToolError, I18n.t("mcp.errors.topic_update_required") if updated_fields.empty?

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
      OUTPUT_SCHEMA =
        OutputSchema.object(post_id: OutputSchema::INTEGER, deleted: OutputSchema::BOOLEAN)

      def self.call(arguments:, request_context:)
        post = Post.find_by(id: arguments.fetch("post_id").to_i, user_id: request_context.user_id)
        raise DiscourseMcp::ToolError, "Post not found" if post.blank?

        if arguments.fetch("deleted")
          raise Discourse::InvalidAccess if !request_context.guardian.can_delete_post?(post)
          PostDestroyer.new(request_context.user, post).destroy
        else
          raise Discourse::InvalidAccess if !request_context.guardian.can_recover_post?(post)
          PostDestroyer.new(request_context.user, post).recover
        end
        ToolHelpers.text_and_structured(post_id: post.id, deleted: arguments.fetch("deleted"))
      end
    end
  end
end
