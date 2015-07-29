require_dependency 'pinned_check'
require_dependency 'new_post_manager'

class TopicViewSerializer < ApplicationSerializer
  include PostStreamSerializerMixin

  def self.attributes_from_topic(*list)
    [list].flatten.each do |attribute|
      attributes(attribute)
      class_eval %{def #{attribute}
        object.topic.#{attribute}
      end}
    end
  end

  attributes_from_topic :id,
                        :title,
                        :fancy_title,
                        :posts_count,
                        :created_at,
                        :views,
                        :reply_count,
                        :participant_count,
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
                        :pending_posts_count,
                        :user_id

  attributes :draft,
             :draft_key,
             :draft_sequence,
             :posted,
             :unpinned,
             :pinned_globally,
             :pinned,    # Is topic pinned and viewer hasn't cleared the pin?
             :pinned_at, # Ignores clear pin
             :pinned_until,
             :details,
             :highest_post_number,
             :last_read_post_number,
             :deleted_by,
             :has_deleted,
             :actions_summary,
             :expandable_first_post,
             :is_warning,
             :chunk_size,
             :bookmarked

  # TODO: Split off into proper object / serializer
  def details
    result = {
      auto_close_at: object.topic.auto_close_at,
      auto_close_hours: object.topic.auto_close_hours,
      auto_close_based_on_last_post: object.topic.auto_close_based_on_last_post,
      created_by: BasicUserSerializer.new(object.topic.user, scope: scope, root: false),
      last_poster: BasicUserSerializer.new(object.topic.last_poster, scope: scope, root: false)
    }

    if object.topic.allowed_users.present?
      result[:allowed_users] = object.topic.allowed_users.map do |user|
        BasicUserSerializer.new(user, scope: scope, root: false)
      end
    end

    if object.topic.allowed_groups.present?
      result[:allowed_groups] = object.topic.allowed_groups.map do |ag|
        BasicGroupSerializer.new(ag, scope: scope, root: false)
      end
    end

    if object.post_counts_by_user.present?
      result[:participants] = object.post_counts_by_user.map do |pc|
        TopicPostCountSerializer.new({user: object.participants[pc[0]], post_count: pc[1]}, scope: scope, root: false)
      end
    end


    if object.suggested_topics.try(:topics).present?
      result[:suggested_topics] = object.suggested_topics.topics.map do |user|
        SuggestedTopicSerializer.new(user, scope: scope, root: false)
      end
    end

    if object.links.present?
      result[:links] = object.links.map do |user|
        TopicLinkSerializer.new(user, scope: scope, root: false)
      end
    end

    if has_topic_user?
      result[:notification_level] = object.topic_user.notification_level
      result[:notifications_reason_id] = object.topic_user.notifications_reason_id
    else
      result[:notification_level] = TopicUser.notification_levels[:regular]
    end

    result[:can_move_posts] = true if scope.can_move_posts?(object.topic)
    result[:can_edit] = true if scope.can_edit?(object.topic)
    result[:can_delete] = true if scope.can_delete?(object.topic)
    result[:can_recover] = true if scope.can_recover_topic?(object.topic)
    result[:can_remove_allowed_users] = true if scope.can_remove_allowed_users?(object.topic)
    result[:can_invite_to] = true if scope.can_invite_to?(object.topic)
    result[:can_create_post] = true if scope.can_create?(Post, object.topic)
    result[:can_reply_as_new_topic] = true if scope.can_reply_as_new_topic?(object.topic)
    result[:can_flag_topic] = actions_summary.any? { |a| a[:can_act] }
    result
  end

  def chunk_size
    object.chunk_size
  end

  def is_warning
    object.topic.private_message? && object.topic.subtype == TopicSubtype.moderator_warning
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

  def deleted_by
    BasicUserSerializer.new(object.topic.deleted_by, root: false).as_json
  end

  # Topic user stuff
  def has_topic_user?
    object.topic_user.present?
  end

  def highest_post_number
    object.highest_post_number
  end

  def last_read_post_number
    object.topic_user.last_read_post_number
  end
  alias_method :include_last_read_post_number?, :has_topic_user?

  def posted
    object.topic_user.posted?
  end
  alias_method :include_posted?, :has_topic_user?

  def pinned_globally
    object.topic.pinned_globally
  end

  def pinned
    PinnedCheck.pinned?(object.topic, object.topic_user)
  end

  def unpinned
    PinnedCheck.unpinned?(object.topic, object.topic_user)
  end

  def pinned_at
    object.topic.pinned_at
  end

  def pinned_until
    object.topic.pinned_until
  end

  def actions_summary
    result = []
    return [] unless post = object.posts.try(:first)
    PostActionType.topic_flag_types.each do |sym, id|
      result << { id: id,
                  count: 0,
                  hidden: false,
                  can_act: scope.post_can_act?(post, sym)}
      # TODO: other keys? :can_defer_flags, :acted, :can_undo
    end
    result
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
    object.topic_user.try(:bookmarked)
  end

  def include_pending_posts_count
    scope.user.staff? && NewPostManager.queue_enabled?
  end

end
