# frozen_string_literal: true

module DiscourseAssign
  class CreateNotification
    class UserAssignment
      attr_reader :assignment

      def initialize(assignment)
        @assignment = assignment
      end

      def excerpt_key
        "discourse_assign.topic_assigned_excerpt"
      end

      def notification_message
        "discourse_assign.assign_notification"
      end

      def display_username
        assignment.assigned_by_user.username
      end
    end

    class GroupAssignment < UserAssignment
      def excerpt_key
        "discourse_assign.topic_group_assigned_excerpt"
      end

      def notification_message
        "discourse_assign.assign_group_notification"
      end

      def display_username
        assignment.assigned_to.name
      end
    end

    def self.call(...)
      new(...).call
    end

    attr_reader :assignment, :user, :mark_as_read, :assignment_type
    alias mark_as_read? mark_as_read

    delegate :topic,
             :post,
             :assigned_by_user,
             :assigned_to,
             :created_at,
             :updated_at,
             :assigned_to_user?,
             :id,
             to: :assignment,
             private: true
    delegate :excerpt_key,
             :notification_message,
             :display_username,
             to: :assignment_type,
             private: true

    def initialize(assignment:, user:, mark_as_read:)
      @assignment = assignment
      @user = user
      @mark_as_read = mark_as_read
      @assignment_type =
        "#{self.class}::#{assignment.assigned_to.class}Assignment".constantize.new(assignment)
    end

    def call
      return if topic.nil?
      Assigner.publish_topic_tracking_state(topic, user.id)
      unless mark_as_read?
        PostAlerter.new(post).create_notification_alert(
          user: user,
          post: post,
          username: assigned_by_user.username,
          notification_type: Notification.types[:assigned],
          excerpt:
            I18n.t(
              excerpt_key,
              title: topic.title,
              group: assigned_to.name,
              locale: user.effective_locale,
            ),
        )
      end
      user.notifications.assigned.create!(
        created_at: created_at,
        updated_at: updated_at,
        topic: topic,
        post_number: post.post_number,
        high_priority: true,
        read: mark_as_read?,
        data: {
          message: notification_message,
          display_username: display_username,
          topic_title: topic.title,
          assignment_id: id,
        }.to_json,
      )
    end
  end
end
