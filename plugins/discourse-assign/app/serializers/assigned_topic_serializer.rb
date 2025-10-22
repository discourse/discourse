# frozen_string_literal: true

class AssignedTopicSerializer < BasicTopicSerializer
  include TopicTagsMixin

  attributes :excerpt, :category_id, :created_at, :updated_at, :assigned_to_user, :assigned_to_group

  has_one :user, serializer: BasicUserSerializer, embed: :objects

  def assigned_to_user
    BasicUserSerializer.new(object.assigned_to, scope: scope, root: false).as_json
  end

  def include_assigned_to_user?
    object.assignment.assigned_to_user? && object.assignment.active
  end

  def assigned_to_group
    BasicGroupSerializer.new(object.assigned_to, scope: scope, root: false).as_json
  end

  def include_assigned_to_group?
    object.assignment.assigned_to_group? && object.assignment.active
  end
end
