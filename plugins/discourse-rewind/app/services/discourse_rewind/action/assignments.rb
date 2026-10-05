# frozen_string_literal: true

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

        assigned = Assignment.where(assigned_to: user)
        assigned_this_year = assigned.where(created_at: date)
        total_assigned = assigned_this_year.count

        return if total_assigned == 0

        completed_count =
          assigned_this_year
            .joins(:topic)
            .where(
              "topics.closed = true OR assignments.active = false OR assignments.updated_at > assignments.created_at",
            )
            .count
        pending_count = assigned.active.joins(:topic).where(topics: { closed: false }).count

        return if completed_count == 0 && pending_count == 0

        {
          data: {
            total_assigned:,
            completed: completed_count,
            pending: pending_count,
            assigned_by_user: Assignment.where(assigned_by_user: user, created_at: date).count,
            completion_rate: (completed_count.to_f / total_assigned * 100).round(1),
          },
          identifier: "assignments",
        }
      end

      def self.enabled?
        plugin_enabled?("discourse-assign")
      end
    end
  end
end
