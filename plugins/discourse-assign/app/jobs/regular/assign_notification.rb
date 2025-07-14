# frozen_string_literal: true

module Jobs
  class AssignNotification < ::Jobs::Base
    def execute(args)
      raise Discourse::InvalidParameters.new(:assignment_id) if args[:assignment_id].nil?
      return if SilencedAssignment.exists?(assignment_id: args[:assignment_id])

      Assignment.find(args[:assignment_id]).create_missing_notifications!
    end
  end
end
