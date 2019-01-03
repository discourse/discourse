require_dependency 'reviewable_action_serializer'
require_dependency 'reviewable_editable_field_serializer'

class ReviewableSerializer < ApplicationSerializer

  class_attribute :_payload_for_serialization

  attributes(
    :id,
    :status,
    :type,
    :topic_id,
    :category_id,
    :created_at,
    :can_edit,
    :score,
    :version
  )

  has_one :created_by, serializer: BasicUserSerializer, root: 'users'
  has_one :target_created_by, serializer: BasicUserSerializer, root: 'users'
  has_one :topic, serializer: ListableTopicSerializer
  has_many :editable_fields, serializer: ReviewableEditableFieldSerializer, embed: :objects
  has_many :reviewable_scores, serializer: ReviewableScoreSerializer
  has_many :bundled_actions, serializer: ReviewableBundledActionSerializer

  # Used to keep track of our payload attributes
  class_attribute :_payload_for_serialization

  def bundled_actions
    object.actions_for(scope).bundles
  end

  def reviewable_actions
    object.actions_for(scope).to_a
  end

  def editable_fields
    object.editable_for(scope).to_a
  end

  def can_edit
    editable_fields.present?
  end

  def self.create_attribute(name, field)
    attribute(name)

    class_eval <<~GETTER
      def #{name}
        #{field}
      end

      def include_#{name}?
        #{name}.present?
      end
    GETTER
  end

  # This is easier than creating an AMS method for each attribute
  def self.target_attributes(*attributes)
    attributes.each do |a|
      create_attribute(a, "object.target&.#{a}")
    end
  end

  def self.payload_attributes(*attributes)
    self._payload_for_serialization ||= []
    self._payload_for_serialization += attributes.map(&:to_s)
  end

  def attributes
    data = super

    if object.target.present?
      # Automatically add the target id as a "good name" for example a target_type of `User`
      # becomes `user_id`
      data[:"#{object.target_type.downcase}_id"] = object.target_id
    end

    if self.class._payload_for_serialization.present?
      data[:payload] = object.payload.slice(*self.class._payload_for_serialization)
    end

    data
  end

  def include_topic_id?
    object.topic_id.present?
  end

  def include_category_id?
    object.category_id.present?
  end

end
