require_dependency 'pinned_check'
require_dependency 'new_post_manager'

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

  attributes_from_topic :id,
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
                        :pinned_until

  attributes :draft,
             :draft_key,
             :draft_sequence,
             :posted,
             :unpinned,
             :pinned,
             :details,
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
             :pm_with_non_human_user

  # TODO: Split off into proper object / serializer
  def details
    topic = object.topic

    result = {
      created_by: BasicUserSerializer.new(topic.user, scope: scope, root: false),
      last_poster: BasicUserSerializer.new(topic.last_poster, scope: scope, root: false)
    }

    if private_message?(topic)
      allowed_user_ids = Set.new

      result[:allowed_groups] = object.topic.allowed_groups.map do |group|
        allowed_user_ids.merge(GroupUser.where(group: group).pluck(:user_id))
        BasicGroupSerializer.new(group, scope: scope, root: false)
      end

      result[:allowed_users] = object.topic.allowed_users.select do |user|
        !allowed_user_ids.include?(user.id)
      end.map! do |user|
        BasicUserSerializer.new(user, scope: scope, root: false)
      end
    end

    if object.post_counts_by_user.present?
      participants = object.post_counts_by_user.reject { |p| object.participants[p].blank? }.map do |pc|
        TopicPostCountSerializer.new({ user: object.participants[pc[0]], post_count: pc[1] }, scope: scope, root: false)
      end
      result[:participants] = participants if participants.length > 0
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
    result[:can_remove_self_id] = scope.user.id if scope.can_remove_allowed_users?(object.topic, scope.user)
    result[:can_invite_to] = true if scope.can_invite_to?(object.topic)
    result[:can_invite_via_email] = true if scope.can_invite_via_email?(object.topic)
    result[:can_create_post] = true if scope.can_create?(Post, object.topic)
    result[:can_reply_as_new_topic] = true if scope.can_reply_as_new_topic?(object.topic)
    result[:can_flag_topic] = actions_summary.any? { |a| a[:can_act] }
    result[:can_convert_topic] = true if scope.can_convert_topic?(object.topic)
    result
  end

  def message_bus_last_id
    object.message_bus_last_id
  end

  def chunk_size
    object.chunk_size
  end

  def is_warning
    private_message?(object.topic) && object.topic.subtype == TopicSubtype.moderator_warning
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
    private_message?(object.topic)
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
    result = []
    return [] unless post = object.posts&.first
    PostActionType.topic_flag_types.each do |sym, id|
      result << { id: id,
                  count: 0,
                  hidden: false,
                  can_act: scope.post_can_act?(post, sym) }
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
    private_message?(object.topic)
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

  private

  def private_message?(topic)
    @private_message ||= topic.private_message?
  end

end
