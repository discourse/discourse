# frozen_string_literal: true

class ReviewableSerializer < ApplicationSerializer
  class_attribute :_payload_for_serialization

  attributes(
    :id,
    :type,
    :type_source,
    :topic_id,
    :topic_url,
    :target_type,
    :target_id,
    :target_url,
    :target_created_at,
    :target_deleted_at,
    :topic_tags,
    :category_id,
    :created_at,
    :can_edit,
    :score,
    :version,
    :target_created_by_trust_level,
    :created_from_flag?,
  )

  attribute :status_for_database, key: :status

  has_one :created_by, serializer: UserWithCustomFieldsSerializer, root: "users"
  has_one :target_created_by, root: "users"
  has_one :target_deleted_by, serializer: BasicUserSerializer, root: "users"
  has_one :topic, serializer: ListableTopicSerializer
  has_many :editable_fields, serializer: ReviewableEditableFieldSerializer, embed: :objects
  has_many :reviewable_scores, serializer: ReviewableScoreSerializer
  has_many :bundled_actions, serializer: ReviewableBundledActionSerializer
  has_many :reviewable_notes, serializer: ReviewableNoteSerializer
  has_many :reviewable_histories, serializer: ReviewableHistorySerializer
  has_one :claimed_by, serializer: ReviewableClaimedTopicSerializer

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
    return nil if @options[:claimed_topics].blank?
    @options[:claimed_topics][object.topic_id]
  end

  def include_claimed_by?
    @options[:claimed_topics]
  end

  def self.create_attribute(name, field)
    attribute(name)

    class_eval <<~RUBY
      def #{name}
        #{field}
      end

      def include_#{name}?
        #{name}.present?
      end
    RUBY
  end

  # This is easier than creating an AMS method for each attribute
  def self.target_attributes(*attributes)
    attributes.each { |a| create_attribute(a, "object.target&.#{a}") }
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

  def created_from_flag?
    false
  end

  def topic_tags
    object.topic.tags.map(&:name)
  end

  def include_topic_tags?
    object.topic.present? && SiteSetting.tagging_enabled?
  end

  def target_created_at
    object.target&.created_at
  end

  def include_target_created_at?
    object.target_type == "Post"
  end

  def target_url
    if object.target.is_a?(Post) && object.target.present?
      return Discourse.base_url + object.target.url
    end
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

  def target_created_by_trust_level
    object&.target_created_by&.trust_level
  end

  def target_deleted_at
    target = target_post_with_deleted
    return target.deleted_at if target&.deleted_at.present?
    target.revisions.order(created_at: :desc).pick(:created_at) if target&.user_deleted?
  end

  def include_target_deleted_at?
    include_target_deleted_by? && target_deleted_at.present?
  end

  def target_deleted_by
    target = target_post_with_deleted
    target&.deleted_by || (target if target&.user_deleted?)&.user
  end

  def include_target_deleted_by?
    return false unless object.target_type == "Post"
    target = target_post_with_deleted
    target&.deleted_by_id.present? || target&.user_deleted?
  end

  def target_post_with_deleted
    return @target_post_with_deleted if defined?(@target_post_with_deleted)
    @target_post_with_deleted =
      object.target_type == "Post" ? Post.with_deleted.find_by(id: object.target_id) : nil
  end

  def target_created_by
    user =
      if object.target_type == "User"
        object.target
      else
        object.target_created_by
      end

    return if user.blank?

    serializer_class =
      scope.can_see_reviewable_ui_refresh? ? FlaggedUserSerializer : UserWithCustomFieldsSerializer
    serializer_class.new(user, scope:, root: false)
  end
end
