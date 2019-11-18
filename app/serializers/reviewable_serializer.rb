# frozen_string_literal: true

class ReviewableSerializer < ApplicationSerializer

  class_attribute :_payload_for_serialization

  attributes(
    :id,
    :status,
    :type,
    :topic_id,
    :topic_url,
    :target_url,
    :topic_tags,
    :category_id,
    :created_at,
    :can_edit,
    :score,
    :version,
  )

  has_one :created_by, serializer: BasicUserSerializer, root: 'users'
  has_one :target_created_by, serializer: BasicUserSerializer, root: 'users'
  has_one :topic, serializer: ListableTopicSerializer
  has_many :editable_fields, serializer: ReviewableEditableFieldSerializer, embed: :objects
  has_many :reviewable_scores, serializer: ReviewableScoreSerializer
  has_many :bundled_actions, serializer: ReviewableBundledActionSerializer
  has_one :claimed_by, serializer: BasicUserSerializer, root: 'users'

  # Used to keep track of our payload attributes
  class_attribute :_payload_for_serialization

  def bundled_actions
    args = {}
    args[:claimed_by] = claimed_by if @options[:claimed_topics]
    object.actions_for(scope, args).bundles
  end

  def editable_fields
    args = {}
    args[:claimed_by] = claimed_by if @options[:claimed_topics]
    object.editable_for(scope, args).to_a
  end

  def can_edit
    editable_fields.present?
  end

  def claimed_by
    return nil unless @options[:claimed_topics].present?
    @options[:claimed_topics][object.topic_id]
  end

  def include_claimed_by?
    @options[:claimed_topics]
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
    super.tap do |data|
      data[:removed_topic_id] = object.topic_id unless object.topic

      if object.target.present?
        # Automatically add the target id as a "good name" for example a target_type of `User`
        # becomes `user_id`
        data[:"#{object.target_type.downcase}_id"] = object.target_id
      end

      if self.class._payload_for_serialization.present?
        data[:payload] = (object.payload || {}).slice(*self.class._payload_for_serialization)
      end
    end
  end

  def topic_tags
    object.topic.tags.map(&:name)
  end

  def include_topic_tags?
    object.topic.present? && SiteSetting.tagging_enabled?
  end

  def target_url
    return Discourse.base_url + object.target.url if object.target.is_a?(Post) && object.target.present?
    topic_url
  end

  def include_target_url?
    target_url.present?
  end

  def topic_url
    object.topic&.url
  end

  def include_topic_url?
    topic_url.present?
  end

  def include_topic_id?
    object.topic_id.present?
  end

  def include_category_id?
    object.category_id.present?
  end

end
