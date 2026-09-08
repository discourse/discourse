# frozen_string_literal: true

module Boards
  class TopicMutator
    class << self
      def apply!(topic:, column:, guardian:)
        return unless mutates_topic?(column)

        user = guardian.user
        raise Discourse::InvalidAccess.new unless user
        raise Discourse::InvalidAccess.new unless guardian.can_edit?(topic)

        move_topic_to_category(topic, column, guardian, user)
        move_topic_tags(topic, column, guardian)
        move_topic_assignment(topic, column, guardian, user)
        move_topic_status(topic, column, guardian, user)
      end

      def mutates_topic?(column)
        return true if column.move_to_category_id.present?
        return true if column.move_to_status.present?
        return true if column.move_to_assigned.present?
        column.board.columns.any? { |c| c.tag_id.present? }
      end

      def move_topic_to_category(topic, column, guardian, user)
        return if column.move_to_category_id.blank?

        category = Category.find_by(id: column.move_to_category_id)
        raise Discourse::NotFound.new if category.blank?

        guardian.ensure_can_move_topic_to_category!(category)

        options = {
          bypass_bump: true,
          validate_post: false,
          bypass_rate_limiter: true,
          skip_revision: true,
        }

        topic.first_post.revise(user, { category_id: category.id }, options)
      end

      def move_topic_tags(topic, column, guardian)
        resolved_tag_ids =
          ColumnTagResolver.resolve_tag_ids(current_tag_ids: topic.tag_ids, column:)
        return if resolved_tag_ids.sort == topic.tag_ids.sort

        updated_tags = Card.ordered_tags(resolved_tag_ids).map(&:name)
        DiscourseTagging.tag_topic_by_names(topic, guardian, updated_tags)
      end

      def move_topic_assignment(topic, column, guardian, user)
        return if column.move_to_assigned.blank?
        return unless defined?(::Assigner)

        return if column.move_to_assigned == "*"

        validate_assignment_permission!(topic, guardian)

        assigner = ::Assigner.new(topic, user)

        case column.move_to_assigned
        when "nobody"
          assigner.unassign
          topic
            .posts
            .joins(:assignment)
            .where(assignments: { active: true })
            .find_each { |post| ::Assigner.new(post, user).unassign }
        else
          target = User.find_by(username_lower: column.move_to_assigned.downcase)
          target ||= Group.find_by(name: column.move_to_assigned)
          assigner.assign(target) if target
        end
      end

      def move_topic_status(topic, column, guardian, user)
        return if column.move_to_status.blank?

        enabled = column.move_to_status == "closed"
        validate_status_permission!(topic, guardian, enabled)
        topic.update_status("closed", enabled, user)
      end

      def validate_assignment_permission!(topic, guardian)
        raise Discourse::InvalidAccess.new unless guardian.respond_to?(:can_assign?)
        raise Discourse::InvalidAccess.new unless guardian.can_assign?(topic)
      end

      def validate_status_permission!(topic, guardian, closing)
        allowed = closing ? guardian.can_close_topic?(topic) : guardian.can_open_topic?(topic)
        raise Discourse::InvalidAccess.new unless allowed
      end
    end
  end
end
