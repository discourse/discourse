# frozen_string_literal: true

class TopicViewSerializer < ApplicationSerializer
  include PostStreamSerializerMixin
  include SuggestedTopicsMixin
  include TopicTagsMixin
  include ApplicationHelper

  def self.attributes_from_topic(*list)
    [list].flatten.each do |attribute|
      attributes(attribute)
      class_eval %{def #{attribute}
        object.topic.#{attribute}
      end}
    end
  end

  attributes_from_topic(
    :id,
    :title,
    :fancy_title,
    :posts_count,
    :created_at,
    :views,
    :reply_count,
    :like_count,
    :last_posted_at,
    :visible,
    :closed,
    :archived,
    :has_summary,
    :archetype,
    :slug,
    :category_id,
    :word_count,
    :deleted_at,
    :user_id,
    :featured_link,
    :featured_link_root_domain,
    :pinned_globally,
    :pinned_at,
    :pinned_until,
    :image_url
  )

  attributes(
    :draft,
    :draft_key,
    :draft_sequence,
    :posted,
    :unpinned,
    :pinned,
    :current_post_number,
    :highest_post_number,
    :last_read_post_number,
    :last_read_post_id,
    :deleted_by,
    :has_deleted,
    :actions_summary,
    :expandable_first_post,
    :is_warning,
    :chunk_size,
    :bookmarked,
    :message_archived,
    :topic_timer,
    :private_topic_timer,
    :unicode_title,
    :message_bus_last_id,
    :participant_count,
    :destination_category_id,
    :pm_with_non_human_user,
    :queued_posts_count,
    :show_read_indicator
  )

  has_one :details, serializer: TopicViewDetailsSerializer, root: false, embed: :objects
  has_many :pending_posts, serializer: TopicPendingPostSerializer, root: false, embed: :objects

  def details
    object
  end

  def message_bus_last_id
    object.message_bus_last_id
  end

  def chunk_size
    object.chunk_size
  end

  def is_warning
    object.personal_message && object.topic.subtype == TopicSubtype.moderator_warning
  end

  def include_is_warning?
    is_warning
  end

  def draft
    object.draft
  end

  def draft_key
    object.draft_key
  end

  def draft_sequence
    object.draft_sequence
  end

  def include_message_archived?
    object.personal_message
  end

  def message_archived
    object.topic.message_archived?(scope.user)
  end

  def deleted_by
    BasicUserSerializer.new(object.topic.deleted_by, root: false).as_json
  end

  # Topic user stuff
  def has_topic_user?
    object.topic_user.present?
  end

  def current_post_number
    object.current_post_number
  end

  def include_current_post_number?
    object.current_post_number.present?
  end

  def highest_post_number
    object.highest_post_number
  end

  def last_read_post_id
    return nil unless last_read_post_number
    object.filtered_post_id(last_read_post_number)
  end
  alias_method :include_last_read_post_id?, :has_topic_user?

  def last_read_post_number
    @last_read_post_number ||= object.topic_user.last_read_post_number
  end
  alias_method :include_last_read_post_number?, :has_topic_user?

  def posted
    object.topic_user.posted?
  end
  alias_method :include_posted?, :has_topic_user?

  def pinned
    PinnedCheck.pinned?(object.topic, object.topic_user)
  end

  def unpinned
    PinnedCheck.unpinned?(object.topic, object.topic_user)
  end

  def actions_summary
    object.actions_summary
  end

  def has_deleted
    object.has_deleted?
  end

  def include_has_deleted?
    object.guardian.can_see_deleted_posts?
  end

  def expandable_first_post
    true
  end

  def include_expandable_first_post?
    object.topic.expandable_first_post?
  end

  def bookmarked
    object.topic_user&.bookmarked
  end

  def topic_timer
    TopicTimerSerializer.new(object.topic.public_topic_timer, root: false)
  end

  def include_private_topic_timer?
    scope.user
  end

  def private_topic_timer
    timer = object.topic.private_topic_timer(scope.user)
    TopicTimerSerializer.new(timer, root: false)
  end

  def include_featured_link?
    SiteSetting.topic_featured_link_enabled
  end

  def include_featured_link_root_domain?
    SiteSetting.topic_featured_link_enabled && object.topic.featured_link
  end

  def include_unicode_title?
    object.topic.title.match?(/:[\w\-+]+:/)
  end

  def unicode_title
    Emoji.gsub_emoji_to_unicode(object.topic.title)
  end

  def include_pm_with_non_human_user?
    object.personal_message
  end

  def pm_with_non_human_user
    object.topic.pm_with_non_human_user?
  end

  def participant_count
    object.participant_count
  end

  def destination_category_id
    object.topic.shared_draft.category_id
  end

  def include_destination_category_id?
    scope.can_create_shared_draft? &&
      object.topic.category_id == SiteSetting.shared_drafts_category.to_i &&
      object.topic.shared_draft.present?
  end

  def include_pending_posts?
    scope.authenticated? && object.queued_posts_enabled
  end

  def queued_posts_count
    object.queued_posts_count
  end

  def include_queued_posts_count?
    scope.is_staff? && object.queued_posts_enabled
  end

  def show_read_indicator
    object.show_read_indicator?
  end
end
