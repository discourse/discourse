# frozen_string_literal: true

module DiscourseAssign
  class AssignmentSerializer < ApplicationSerializer
    attributes :id, :target_id, :target_type, :assigned_to_type, :assigned_to, :note, :status

    def assigned_to
      serializer = object.assigned_to_user? ? BasicUserSerializer : AssignedGroupSerializer
      serializer.new(object.assigned_to, scope:, root: false).as_json
    end

    def include_status?
      SiteSetting.enable_assign_status
    end
  end
end
