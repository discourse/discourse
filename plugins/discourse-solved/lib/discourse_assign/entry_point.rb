# frozen_string_literal: true

module DiscourseAssign
  class EntryPoint
    # TODO: These four plugin api usages should ideally be in the assign plugin, not the solved plugin.
    # They have been moved here from plugin.rb as part of the custom fields migration.

    def self.inject(plugin)
      plugin.register_modifier(:assigns_reminder_assigned_topics_query) do |query|
        next query if !SiteSetting.ignore_solved_topics_in_assigned_reminder
        query.where.not(id: DiscourseSolved::SolvedTopic.select(:topic_id))
      end

      plugin.register_modifier(:assigned_count_for_user_query) do |query, user|
        next query if !SiteSetting.ignore_solved_topics_in_assigned_reminder
        next query if SiteSetting.assignment_status_on_solve.blank?
        query.where.not(status: SiteSetting.assignment_status_on_solve)
      end

      plugin.on(:accepted_solution) do |post|
        next if SiteSetting.assignment_status_on_solve.blank?
        assignments = Assignment.includes(:target).where(topic: post.topic)
        assignments.each do |assignment|
          assigned_user = User.find_by(id: assignment.assigned_to_id)
          Assigner.new(assignment.target, assigned_user).assign(
            assigned_user,
            status: SiteSetting.assignment_status_on_solve,
          )
        end
      end

      plugin.on(:unaccepted_solution) do |post|
        next if SiteSetting.assignment_status_on_unsolve.blank?
        assignments = Assignment.includes(:target).where(topic: post.topic)
        assignments.each do |assignment|
          assigned_user = User.find_by(id: assignment.assigned_to_id)
          Assigner.new(assignment.target, assigned_user).assign(
            assigned_user,
            status: SiteSetting.assignment_status_on_unsolve,
          )
        end
      end
    end
  end
end
