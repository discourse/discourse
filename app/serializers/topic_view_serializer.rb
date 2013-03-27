require_dependency 'pinned_check'

class TopicViewSerializer < ApplicationSerializer

  # These attributes will be delegated to the topic
  def self.topic_attributes
    [:id,
     :title,
     :fancy_title,
     :posts_count,
     :created_at,
     :views,
     :reply_count,
     :last_posted_at,
     :visible,
     :closed,
     :archived,
     :moderator_posts_count,
     :has_best_of,
     :archetype,
     :slug]
  end

  def self.guardian_attributes
    [:can_moderate, :can_edit, :can_delete, :can_invite_to, :can_move_posts]
  end

  attributes *topic_attributes
  attributes *guardian_attributes

  attributes :draft,
             :draft_key,
             :draft_sequence,
             :post_action_visibility,
             :voted_in_topic,
             :can_create_post,
             :can_reply_as_new_topic,
             :categoryName,
             :starred,
             :last_read_post_number,
             :posted,
             :notification_level,
             :notifications_reason_id,
             :posts,
             :at_bottom,
             :highest_post_number,
             :pinned,
             :filtered_posts_count

  has_one :created_by, serializer: BasicUserSerializer, embed: :objects
  has_one :last_poster, serializer: BasicUserSerializer, embed: :objects
  has_many :allowed_users, serializer: BasicUserSerializer, embed: :objects

  has_many :links, serializer: TopicLinkSerializer, embed: :objects
  has_many :participants, serializer: TopicPostCountSerializer, embed: :objects
  has_many :suggested_topics, serializer: SuggestedTopicSerializer, embed: :objects

  # Define a delegator for each attribute of the topic we want
  topic_attributes.each do |ta|
    class_eval %{def #{ta}
      object.topic.#{ta}
    end}
  end

  # Define the guardian attributes
  guardian_attributes.each do |ga|
    class_eval %{
      def #{ga}
        true
      end

      def include_#{ga}?
        scope.#{ga}?(object.topic)
      end
    }
  end

  def draft
    object.draft
  end

  def include_allowed_users?
    object.topic.private_message?
  end

  def draft_key
    object.draft_key
  end

  def draft_sequence
    object.draft_sequence
  end

  def post_action_visibility
    object.post_action_visibility
  end

  def include_post_action_visibility?
    object.post_action_visibility.present?
  end

  def filtered_posts_count
    object.filtered_posts_count
  end

  def voted_in_topic
    object.voted_in_topic?
  end

  def can_reply_as_new_topic
    true
  end

  def include_can_reply_as_new_topic?
    scope.can_reply_as_new_topic?(object.topic)
  end

  def can_create_post
    true
  end

  def include_can_create_post?
    scope.can_create?(Post, object.topic)
  end

  def categoryName
    object.topic.category.name
  end
  def include_categoryName?
    object.topic.category.present?
  end

  # Topic user stuff
  def has_topic_user?
    object.topic_user.present?
  end

  def starred
    object.topic_user.starred?
  end
  alias_method :include_starred?, :has_topic_user?

  def last_read_post_number
    object.topic_user.last_read_post_number
  end
  alias_method :include_last_read_post_number?, :has_topic_user?

  def posted
    object.topic_user.posted?
  end
  alias_method :include_posted?, :has_topic_user?

  def notification_level
    object.topic_user.notification_level
  end
  alias_method :include_notification_level?, :has_topic_user?

  def notifications_reason_id
    object.topic_user.notifications_reason_id
  end
  alias_method :include_notifications_reason_id?, :has_topic_user?

  def created_by
    object.topic.user
  end

  def last_poster
    object.topic.last_poster
  end

  def allowed_users
    object.topic.allowed_users
  end

  def include_links?
    object.links.present?
  end

  def participants
    object.post_counts_by_user.collect {|tuple| {user: object.participants[tuple.first], post_count: tuple[1]}}
  end

  def include_participants?
    object.initial_load? && object.post_counts_by_user.present?
  end

  def suggested_topics
    object.suggested_topics.topics
  end
  def include_suggested_topics?
    at_bottom && object.suggested_topics.present?
  end

  # Whether we're at the bottom of a topic (last page)
  def at_bottom
    posts.present? && (@highest_number_in_posts == object.highest_post_number)
  end

  def highest_post_number
    object.highest_post_number
  end

  def pinned
    PinnedCheck.new(object.topic, object.topic_user).pinned?
  end

  def posts
    return @posts if @posts.present?
    @posts = []
    @highest_number_in_posts = 0
    if object.posts.present?
      object.posts.each_with_index do |p, idx|
        @highest_number_in_posts = p.post_number if p.post_number > @highest_number_in_posts
        ps = PostSerializer.new(p, scope: scope, root: false)
        ps.topic_slug = object.topic.slug
        ps.topic_view = object
        p.topic = object.topic

        post_json = ps.as_json

        if object.index_reverse
          post_json[:index] = object.index_offset - idx
        else
          post_json[:index] = object.index_offset + idx + 1
        end

        @posts << post_json
      end
    end
    @posts
  end

end
