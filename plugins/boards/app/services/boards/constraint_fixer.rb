# frozen_string_literal: true

module Boards
  module ConstraintFixer
    class << self
      # Validates and applies a constraint_fix hash to make a topic conform to
      # a board's category/tag constraints.  Must be called inside a transaction
      # when the caller needs atomicity with later writes.
      #
      #   fix  – ActionController::Parameters or Hash with optional keys:
      #          "category_id" (integer) and/or "tag_names" (array of strings)
      #   board, topic, guardian – the usual context objects
      #
      def apply!(fix:, board:, topic:, guardian:)
        apply_category_fix!(fix, board, topic, guardian) if fix["category_id"].present?
        apply_tag_fix!(fix, board, topic, guardian) if fix["tag_names"].present?
      end

      private

      def apply_category_fix!(fix, board, topic, guardian)
        if board.category_ids.blank?
          raise Discourse::InvalidParameters.new(
                  I18n.t("boards.errors.topic_does_not_match_constraints"),
                )
        end

        category_id = fix["category_id"].to_i
        if board.category_ids.exclude?(category_id)
          raise Discourse::InvalidParameters.new(
                  I18n.t("boards.errors.topic_does_not_match_constraints"),
                )
        end

        category = Category.find_by(id: category_id)
        raise Discourse::NotFound if category.blank?
        guardian.ensure_can_edit!(topic)
        guardian.ensure_can_move_topic_to_category!(category)

        first_post = topic.first_post || topic.posts.with_deleted.order(:post_number).first
        raise Discourse::NotFound if first_post.blank?

        first_post.revise(
          guardian.user,
          { category_id: category.id },
          {
            bypass_bump: true,
            validate_post: false,
            bypass_rate_limiter: true,
            skip_revision: true,
          },
        )
        topic.reload
      end

      def apply_tag_fix!(fix, board, topic, guardian)
        if board.tag_ids.blank?
          raise Discourse::InvalidParameters.new(
                  I18n.t("boards.errors.topic_does_not_match_constraints"),
                )
        end

        board_tag_names = Tag.where(id: board.tag_ids).pluck(:name)
        requested_tags = Array(fix["tag_names"])
        unless requested_tags.all? { |t| board_tag_names.include?(t) }
          raise Discourse::InvalidParameters.new(
                  I18n.t("boards.errors.topic_does_not_match_constraints"),
                )
        end

        guardian.ensure_can_edit_tags!(topic)

        current_tags = topic.tags.map(&:name)
        updated_tags = (current_tags + requested_tags).uniq
        DiscourseTagging.tag_topic_by_names(topic, guardian, updated_tags)
        topic.reload
      end
    end
  end
end
