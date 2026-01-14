# frozen_string_literal: true

module DiscourseAssign
  module NotificationExtension
    extend ActiveSupport::Concern

    prepended do
      scope :assigned, -> { where(notification_type: Notification.types[:assigned]) }
      scope :for_assignment,
            ->(assignment) do
              assigned.where("((data::jsonb)->'assignment_id')::bigint IN (?)", assignment)
            end
    end
  end
end
