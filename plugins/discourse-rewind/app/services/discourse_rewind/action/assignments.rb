# frozen_string_literal: true

# Assignment statistics using discourse-assign plugin data
# Shows how many assignments, completed, pending, etc.
module DiscourseRewind
  module Action
    class Assignments < BaseReport
      FakeData = {
        data: {
          total_assigned: 24,
          completed: 18,
          pending: 6,
          assigned_by_user: 15,
          completion_rate: 75.0,
        },
        identifier: "assignments",
      }

      def call
        return FakeData if should_use_fake_data?
        return if !enabled?

        # Assignments made to the user
        assignments_scope =
          Assignment.where(assigned_to_id: user.id, assigned_to_type: "User").where(
            created_at: date,
          )

        total_assigned = assignments_scope.count

        # Completed assignments (topics that were assigned and then closed or unassigned)
        completed_count =
          assignments_scope
            .joins(:topic)
            .where(
              "topics.closed = true OR assignments.active = false OR assignments.updated_at > assignments.created_at",
            )
            .distinct
            .count

        # Currently pending (still open and assigned)
        pending_count =
          Assignment
            .where(assigned_to_id: user.id, assigned_to_type: "User", active: true)
            .joins(:topic)
            .where(topics: { closed: false })
            .count

        # Assignments made by the user to others
        assigned_by_user =
          Assignment.where(assigned_by_user_id: user.id).where(created_at: date).count

        {
          data: {
            total_assigned: total_assigned,
            completed: completed_count,
            pending: pending_count,
            assigned_by_user: assigned_by_user,
            completion_rate:
              total_assigned > 0 ? (completed_count.to_f / total_assigned * 100).round(1) : 0,
          },
          identifier: "assignments",
        }
      end

      def enabled?
        Discourse.plugins_by_name["discourse-assign"]&.enabled?
      end
    end
  end
end
