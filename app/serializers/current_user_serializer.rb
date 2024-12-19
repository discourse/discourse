# frozen_string_literal: true

class CurrentUserSerializer < BasicUserSerializer
  include UserTagNotificationsMixin
  include UserSidebarMixin
  include UserStatusMixin

  attributes :name,
             :unread_notifications,
             :unread_high_priority_notifications,
             :all_unread_notifications_count,
             :read_first_notification?,
             :admin?,
             :notification_channel_position,
             :do_not_disturb_channel_position,
             :moderator?,
             :staff?,
             :whisperer?,
             :title,
             :any_posts,
             :trust_level,
             :can_send_private_email_messages,
             :can_send_private_messages,
             :can_upload_avatar,
             :can_edit,
             :can_invite_to_forum,
             :no_password,
             :can_delete_account,
             :can_post_anonymously,
             :can_ignore_users,
             :can_delete_all_posts_and_topics,
             :custom_fields,
             :muted_category_ids,
             :indirectly_muted_category_ids,
             :regular_category_ids,
             :tracked_category_ids,
             :watched_first_post_category_ids,
             :watched_category_ids,
             :watched_tags,
             :watching_first_post_tags,
             :tracked_tags,
             :muted_tags,
             :regular_tags,
             :dismissed_banner_key,
             :is_anonymous,
             :reviewable_count,
             :unseen_reviewable_count,
             :new_personal_messages_notifications_count,
             :read_faq?,
             :previous_visit_at,
             :seen_notification_id,
             :primary_group_id,
             :flair_group_id,
             :can_create_topic,
             :can_create_group,
             :link_posting_access,
             :external_id,
             :associated_account_ids,
             :top_category_ids,
             :groups,
             :needs_required_fields_check?,
             :second_factor_enabled,
             :ignored_users,
             :featured_topic,
             :do_not_disturb_until,
             :has_topic_draft,
             :can_review,
             :draft_count,
             :pending_posts_count,
             :grouped_unread_notifications,
             :display_sidebar_tags,
             :sidebar_tags,
             :sidebar_category_ids,
             :sidebar_sections,
             :new_new_view_enabled?,
             :use_admin_sidebar,
             :can_view_raw_email,
             :login_method,
             :has_unseen_features

  delegate :user_stat, to: :object, private: true
  delegate :any_posts, :draft_count, :pending_posts_count, :read_faq?, to: :user_stat

  has_one :user_option, embed: :object, serializer: CurrentUserOptionSerializer
  has_many :all_sidebar_sections,
           embed: :object,
           key: :sidebar_sections,
           serializer: SidebarSectionSerializer

  def initialize(object, options = {})
    super
    options[:include_status] = true
  end

  def login_method
    @options[:login_method]
  end

  def groups
    owned_group_ids = GroupUser.where(user_id: id, owner: true).pluck(:group_id).to_set

    object
      .visible_groups
      .pluck(:id, :name, :has_messages)
      .map do |id, name, has_messages|
        group = { id: id, name: name, has_messages: has_messages }
        group[:owner] = true if owned_group_ids.include?(id)
        group
      end
  end

  def link_posting_access
    scope.link_posting_access
  end

  def can_create_topic
    scope.can_create_topic?(nil)
  end

  def can_create_group
    scope.can_create_group?
  end

  def include_can_create_group?
    scope.can_create_group?
  end

  def can_send_private_email_messages
    scope.can_send_private_messages_to_email?
  end

  def can_send_private_messages
    scope.can_send_private_messages?
  end

  def use_admin_sidebar
    object.staff? && object.in_any_groups?(SiteSetting.admin_sidebar_enabled_groups_map)
  end

  def include_use_admin_sidebar?
    object.staff?
  end

  def has_unseen_features
    DiscourseUpdates.has_unseen_features?(object.id)
  end

  def include_has_unseen_features?
    object.staff?
  end

  def can_post_anonymously
    SiteSetting.allow_anonymous_posting &&
      (is_anonymous || object.in_any_groups?(SiteSetting.anonymous_posting_allowed_groups_map))
  end

  def can_ignore_users
    scope.can_ignore_users?
  end

  def can_delete_all_posts_and_topics
    object.in_any_groups?(SiteSetting.delete_all_posts_and_topics_allowed_groups_map)
  end

  def can_upload_avatar
    !is_anonymous && object.in_any_groups?(SiteSetting.uploaded_avatars_allowed_groups_map)
  end

  def can_edit
    true
  end

  def can_invite_to_forum
    scope.can_invite_to_forum?
  end

  def include_can_invite_to_forum?
    scope.can_invite_to_forum?
  end

  def no_password
    true
  end

  def include_no_password?
    !object.has_password?
  end

  def include_can_delete_account?
    scope.can_delete_user?(object)
  end

  def can_delete_account
    true
  end

  def custom_fields
    fields = nil
    if SiteSetting.public_user_custom_fields.present?
      fields = SiteSetting.public_user_custom_fields.split("|")
    end
    DiscoursePluginRegistry.serialized_current_user_fields.each do |f|
      fields ||= []
      fields << f
    end

    if fields.present?
      User.custom_fields_for_ids([object.id], fields)[object.id] || {}
    else
      {}
    end
  end

  def muted_category_ids
    categories_with_notification_level(:muted)
  end

  def indirectly_muted_category_ids
    CategoryUser.indirectly_muted_category_ids(object)
  end

  def regular_category_ids
    categories_with_notification_level(:regular)
  end

  def tracked_category_ids
    categories_with_notification_level(:tracking)
  end

  def watched_category_ids
    categories_with_notification_level(:watching)
  end

  def watched_first_post_category_ids
    categories_with_notification_level(:watching_first_post)
  end

  def ignored_users
    IgnoredUser.where(user: object.id).joins(:ignored_user).pluck(:username)
  end

  def top_category_ids
    omitted_notification_levels = [
      CategoryUser.notification_levels[:muted],
      CategoryUser.notification_levels[:regular],
    ]
    CategoryUser
      .where(user_id: object.id)
      .where.not(notification_level: omitted_notification_levels)
      .order(
        "
        CASE
          WHEN notification_level = 3 THEN 1
          WHEN notification_level = 2 THEN 2
          WHEN notification_level = 4 THEN 3
        END",
      )
      .pluck(:category_id)
      .slice(0, SiteSetting.header_dropdown_category_count)
  end

  def dismissed_banner_key
    object.user_profile.dismissed_banner_key
  end

  def is_anonymous
    object.anonymous?
  end

  def can_review
    scope.can_see_review_queue?
  end

  def include_primary_group_id?
    object.primary_group_id.present?
  end

  def external_id
    object&.single_sign_on_record&.external_id
  end

  def include_external_id?
    SiteSetting.enable_discourse_connect
  end

  def associated_account_ids
    values = {}

    object.user_associated_accounts.map do |user_associated_account|
      values[user_associated_account.provider_name] = user_associated_account.provider_uid
    end

    values
  end

  def include_associated_account_ids?
    SiteSetting.include_associated_account_ids
  end

  def second_factor_enabled
    object.totp_enabled? || object.security_keys_enabled?
  end

  def featured_topic
    BasicTopicSerializer.new(object.user_profile.featured_topic, scope: scope, root: false).as_json
  end

  def has_topic_draft
    true
  end

  def include_has_topic_draft?
    Draft.has_topic_draft(object)
  end

  def unseen_reviewable_count
    Reviewable.unseen_reviewable_count(object)
  end

  def can_view_raw_email
    scope.user.in_any_groups?(SiteSetting.view_raw_email_allowed_groups_map)
  end

  def do_not_disturb_channel_position
    MessageBus.last_id("/do-not-disturb/#{object.id}")
  end
end
