# frozen_string_literal: true

module Boards
  class CardTopicSerializer < ApplicationSerializer
    attributes :id,
               :title,
               :unicode_title,
               :slug,
               :category_id,
               :tags,
               :bumped_at,
               :closed,
               :image_url,
               :posts_count,
               :highest_post_number,
               :last_read_post_number

    attribute :last_poster
    attribute :assigned_to_user
    attribute :assigned_to_group
    attribute :all_assigned_users
    attribute :assignments

    def unicode_title
      Emoji.gsub_emoji_to_unicode(object.title)
    end

    def tags
      object.tags.map(&:name)
    end

    def highest_post_number
      (scope.is_whisperer? && object.highest_staff_post_number) || object.highest_post_number
    end

    def last_read_post_number
      topic_user&.last_read_post_number
    end

    def include_last_read_post_number?
      topic_user.present?
    end

    def last_poster
      poster = object.last_poster
      { username: poster.username, avatar_template: poster.avatar_template }
    end

    def include_last_poster?
      object.last_poster.present?
    end

    def assigned_to_user
      assigned = object.assignment.assigned_to
      { username: assigned.username, avatar_template: assigned.avatar_template }
    end

    def include_assigned_to_user?
      assignment_metadata_visible? && object.respond_to?(:assignment) &&
        object.assignment&.assigned_to.is_a?(User)
    end

    def assigned_to_group
      group = object.assignment.assigned_to
      { name: group.name }
    end

    def include_assigned_to_group?
      assignment_metadata_visible? && object.respond_to?(:assignment) &&
        object.assignment&.assigned_to.is_a?(Group)
    end

    def all_assigned_users
      @all_assigned_users ||=
        topic_assignments.filter_map { |a| serialize_user(a.assigned_to) }.uniq { |u| u[:username] }
    end

    def include_all_assigned_users?
      all_assigned_users.present?
    end

    def assignments
      topic_assignments.filter_map { |a| serialize_assignment(a) }
    end

    def include_assignments?
      assignments.present?
    end

    private

    def topic_user
      @topic_user ||= @options.fetch(:topic_users_by_topic, {})[object.id]
    end

    def topic_assignments
      return [] if !assignment_metadata_visible?

      assignments =
        @options.fetch(:assignments_by_topic, {}).fetch(object.id, nil) || fallback_assignments
      assignments.select { |assignment| assignment_target_visible?(assignment) }
    end

    def fallback_assignments
      return [] unless defined?(Assignment)
      Assignment.active.where(topic_id: object.id).includes(:assigned_to, :target)
    end

    def assignment_metadata_visible?
      return false unless defined?(Assignment)

      SiteSetting.assigns_public || (scope.respond_to?(:can_assign?) && scope.can_assign?(object))
    end

    def assignment_target_visible?(assignment)
      return true if assignment.target_type != "Post"

      assignment.target.present? && scope.present? && scope.can_see?(assignment.target)
    end

    def serialize_user(user)
      return unless user.is_a?(User)
      { username: user.username, avatar_template: user.avatar_template }
    end

    def serialize_assignment(assignment)
      assignee = assignment.assigned_to
      result = { target_type: assignment.target_type, target_id: assignment.target_id }

      if assignee.is_a?(User)
        result[:username] = assignee.username
        result[:avatar_template] = assignee.avatar_template
      elsif assignee.is_a?(Group)
        result[:group_name] = assignee.name
      end

      result[:post_number] = assignment.target&.post_number if assignment.target_type == "Post"

      result
    end
  end
end
