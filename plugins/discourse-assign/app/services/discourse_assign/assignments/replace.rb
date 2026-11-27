# frozen_string_literal: true

module DiscourseAssign
  module Assignments
    class Replace
      include Service::Base

      params do
        attribute :topic_id, :integer
        attribute :assignments
        attribute :expected_version, :string

        validates :topic_id, presence: true

        validate do
          unless assignments.is_a?(Array) && assignments.all? { |entry| entry.is_a?(Hash) }
            errors.add(:assignments, :invalid)
            next
          end
          assignments.each do |entry|
            values = entry.symbolize_keys
            valid_assignee =
              %i[username group_name].count do |key|
                values[key].is_a?(String) && values[key].present?
              end == 1
            valid_details =
              %i[note status].all? { |key| values[key].nil? || values[key].is_a?(String) }
            errors.add(:assignments, :invalid) unless valid_assignee && valid_details
          end
        end
      end

      model :topic
      policy :can_assign
      step :replace_assignments

      private

      def fetch_topic(params:, guardian:)
        topic = Topic.find_by(id: params.topic_id)
        topic if topic && guardian.can_see?(topic)
      end

      def can_assign(guardian:, topic:)
        SiteSetting.assign_enabled && guardian.can_assign?(topic)
      end

      def replace_assignments(params:, guardian:, topic:)
        topic.with_lock do
          unless guardian.can_see?(topic) && guardian.can_assign?(topic)
            fail!(reason: :forbidden_assigner_not_allowed)
          end
          if params.expected_version.present? &&
               params.expected_version != Assignment.version_for(topic)
            fail!(reason: :stale_assignments)
          end

          existing = topic.assignments.includes(:assigned_to).to_a
          desired = params.assignments.map(&:symbolize_keys)
          retained_ids = existing.map(&:id)
          if desired.any? { |entry| entry[:id].present? && !retained_ids.include?(entry[:id].to_i) }
            fail!(reason: :invalid_assignment)
          end

          assignees =
            desired.map do |entry|
              DiscourseAssign::AssigneeResolver.resolve!(
                guardian,
                username: entry[:username],
                group_name: entry[:group_name],
              )
            end
          identities = assignees.map { |assignee| [assignee.class.name, assignee.id] }
          fail!(reason: :duplicate_assignee) if identities.uniq.length != identities.length
          if assignees.count { |assignee| assignee.is_a?(Group) } > 1
            fail!(reason: :multiple_groups)
          end

          additions =
            assignees.reject do |assignee|
              existing.any? { |row| row.active && row.assigned_to == assignee }
            end
          if desired.length > 1 && additions.present?
            unless SiteSetting.assign_allow_multiple_topic_assignees
              fail!(reason: :multiple_assignments_disabled)
            end
            unless Assignment.multiple_assignments_ready?
              fail!(reason: :multiple_assignments_not_ready)
            end
          end

          active_count = Assignment.active.where(topic:).count
          final_count = active_count - existing.count(&:active) + desired.length
          if final_count > SiteSetting.assign_max_assignments_per_topic &&
               final_count > active_count
            fail!(reason: :too_many_assigns_for_topic)
          end

          previous_recipients = existing.select(&:active).flat_map(&:assigned_users).map(&:id).uniq
          User.where(id: assignees.grep(User).map(&:id)).order(:id).lock.load
          desired_group = assignees.find { |assignee| assignee.is_a?(Group) }

          existing.each do |assignment|
            replaces_inactive_group =
              assignment.assigned_to_group? && desired_group &&
                desired_group != assignment.assigned_to
            next unless assignment.active || replaces_inactive_group
            if assignees.exclude?(assignment.assigned_to)
              Assigner.new(topic, guardian.user, assignment:).unassign
            end
          end

          desired
            .zip(assignees)
            .each do |entry, assignee|
              assignment = existing.find { |row| row.assigned_to == assignee && !row.destroyed? }
              entry[:note] = assignment.note if assignment && !entry.key?(:note)
              entry[:status] = assignment.status if assignment && !entry.key?(:status)
              if assignment&.active && assignment.note.to_s == entry[:note].to_s &&
                   (!SiteSetting.enable_assign_status || assignment.status == entry[:status])
                next
              end

              result =
                Assigner.new(topic, guardian.user, assignment:, previous_recipients:).assign(
                  assignee,
                  note: entry[:note],
                  status: entry[:status],
                  replace: false,
                )
              fail!(reason: result[:reason], assignee:) unless result[:success]
            end
          topic.reset_assignment_cache
        end
      end
    end
  end
end
