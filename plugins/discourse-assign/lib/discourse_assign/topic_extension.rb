# frozen_string_literal: true

module DiscourseAssign
  module TopicExtension
    extend ActiveSupport::Concern

    prepended do
      has_one :assignment, -> { order(active: :desc, id: :asc) }, as: :target
      has_many :assignments, -> { order(:id) }, as: :target, dependent: :destroy
      has_many :topic_and_post_assignments, class_name: "Assignment", dependent: :destroy
    end

    def active_topic_assignments
      assignments.select { |assignment| assignment.active && assignment.assigned_to }
    end

    def preload_topic_assignments(rows)
      association(:assignments).target = rows
      association(:assignments).loaded!
    end

    def reset_assignment_cache
      association(:assignment).reset
      association(:assignments).reset
      %i[@assigned_to @assignment_status @indirectly_assigned_to].each do |variable|
        remove_instance_variable(variable) if instance_variable_defined?(variable)
      end
    end
  end
end
