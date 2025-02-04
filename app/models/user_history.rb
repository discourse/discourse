# frozen_string_literal: true

# UserHistory stores information about actions that users have taken,
# like deleting users, changing site settings, dismissing notifications, etc.
# Use other classes, like StaffActionLogger, to log records to this table.
class UserHistory < ActiveRecord::Base
  belongs_to :acting_user, class_name: "User"
  belongs_to :target_user, class_name: "User"

  belongs_to :post
  belongs_to :topic
  belongs_to :category

  # Each value in the context should be shorter than this
  MAX_CONTEXT_LENGTH = 50_000

  # We often store multiple values in details, particularly during post edits
  # Let's allow space for 2 values + a little extra for padding
  MAX_DETAILS_LENGTH = 110_000

  MAX_JSON_LENGTH = 300_000

  validates :details, length: { maximum: MAX_DETAILS_LENGTH }
  validates :context, length: { maximum: MAX_CONTEXT_LENGTH }
  validates :subject, length: { maximum: MAX_CONTEXT_LENGTH }
  validates :ip_address, length: { maximum: MAX_CONTEXT_LENGTH }
  validates :email, length: { maximum: MAX_CONTEXT_LENGTH }
  validates :previous_value, length: { maximum: MAX_JSON_LENGTH }
  validates :new_value, length: { maximum: MAX_JSON_LENGTH }

  validates_presence_of :action

  scope :only_staff_actions, -> { where("action IN (?)", UserHistory.staff_action_ids) }

  before_save :set_admin_only

  def self.actions
    @actions ||=
      Enum.new(
        delete_user: 1,
        change_trust_level: 2,
        change_site_setting: 3,
        change_theme: 4,
        delete_theme: 5,
        checked_for_custom_avatar: 6, # not used anymore
        notified_about_avatar: 7,
        notified_about_sequential_replies: 8,
        notified_about_dominating_topic: 9,
        suspend_user: 10,
        unsuspend_user: 11,
        facebook_no_email: 12, # not used anymore
        grant_badge: 13,
        revoke_badge: 14,
        auto_trust_level_change: 15,
        check_email: 16,
        delete_post: 17,
        delete_topic: 18,
        impersonate: 19,
        roll_up: 20,
        change_username: 21,
        custom: 22,
        custom_staff: 23,
        anonymize_user: 24,
        reviewed_post: 25,
        change_category_settings: 26,
        delete_category: 27,
        create_category: 28,
        change_site_text: 29,
        silence_user: 30,
        unsilence_user: 31,
        grant_admin: 32,
        revoke_admin: 33,
        grant_moderation: 34,
        revoke_moderation: 35,
        backup_create: 36,
        rate_limited_like: 37, # not used anymore
        revoke_email: 38,
        deactivate_user: 39,
        wizard_step: 40,
        lock_trust_level: 41,
        unlock_trust_level: 42,
        activate_user: 43,
        change_readonly_mode: 44,
        backup_download: 45,
        backup_destroy: 46,
        notified_about_get_a_room: 47,
        change_name: 48,
        post_locked: 49,
        post_unlocked: 50,
        check_personal_message: 51,
        disabled_second_factor: 52,
        post_edit: 53,
        topic_published: 54,
        recover_topic: 55,
        post_approved: 56,
        create_badge: 57,
        change_badge: 58,
        delete_badge: 59,
        removed_silence_user: 60,
        removed_suspend_user: 61,
        removed_unsilence_user: 62,
        removed_unsuspend_user: 63,
        post_rejected: 64,
        merge_user: 65,
        entity_export: 66,
        change_password: 67,
        topic_timestamps_changed: 68,
        approve_user: 69,
        web_hook_create: 70,
        web_hook_update: 71,
        web_hook_destroy: 72,
        embeddable_host_create: 73,
        embeddable_host_update: 74,
        embeddable_host_destroy: 75,
        web_hook_deactivate: 76,
        change_theme_setting: 77,
        disable_theme_component: 78,
        enable_theme_component: 79,
        api_key_create: 80,
        api_key_update: 81,
        api_key_destroy: 82,
        revoke_title: 83,
        change_title: 84,
        override_upload_secure_status: 85,
        page_published: 86,
        page_unpublished: 87,
        add_email: 88,
        update_email: 89,
        destroy_email: 90,
        topic_closed: 91,
        topic_opened: 92,
        topic_archived: 93,
        topic_unarchived: 94,
        post_staff_note_create: 95,
        post_staff_note_destroy: 96,
        watched_word_create: 97,
        watched_word_destroy: 98,
        delete_group: 99,
        permanently_delete_post_revisions: 100,
        create_public_sidebar_section: 101,
        update_public_sidebar_section: 102,
        destroy_public_sidebar_section: 103,
        reset_bounce_score: 104,
        create_watched_word_group: 105,
        update_watched_word_group: 106,
        delete_watched_word_group: 107,
        redirected_to_required_fields: 108,
        filled_in_required_fields: 109,
        topic_slow_mode_set: 110,
        topic_slow_mode_removed: 111,
        custom_emoji_create: 112,
        custom_emoji_destroy: 113,
        delete_post_permanently: 114,
        delete_topic_permanently: 115,
        tag_group_create: 116,
        tag_group_destroy: 117,
        tag_group_change: 118,
        delete_associated_accounts: 119,
      )
  end

  # Staff actions is a subset of all actions, used to audit actions taken by staff users.
  def self.staff_actions
    @staff_actions ||= %i[
      delete_user
      change_trust_level
      change_site_setting
      change_theme
      delete_theme
      change_site_text
      suspend_user
      unsuspend_user
      removed_suspend_user
      removed_unsuspend_user
      grant_badge
      revoke_badge
      check_email
      delete_post
      delete_topic
      impersonate
      roll_up
      change_username
      custom_staff
      anonymize_user
      reviewed_post
      change_category_settings
      delete_category
      create_category
      silence_user
      unsilence_user
      removed_silence_user
      removed_unsilence_user
      grant_admin
      revoke_admin
      grant_moderation
      revoke_moderation
      backup_create
      revoke_email
      deactivate_user
      lock_trust_level
      unlock_trust_level
      activate_user
      change_readonly_mode
      backup_download
      backup_destroy
      post_locked
      post_unlocked
      check_personal_message
      disabled_second_factor
      post_edit
      topic_published
      recover_topic
      post_approved
      create_badge
      change_badge
      delete_badge
      post_rejected
      merge_user
      entity_export
      change_name
      topic_timestamps_changed
      approve_user
      web_hook_create
      web_hook_update
      web_hook_destroy
      web_hook_deactivate
      embeddable_host_create
      embeddable_host_update
      embeddable_host_destroy
      change_theme_setting
      disable_theme_component
      enable_theme_component
      revoke_title
      change_title
      api_key_create
      api_key_update
      api_key_destroy
      override_upload_secure_status
      page_published
      page_unpublished
      add_email
      update_email
      destroy_email
      topic_closed
      topic_opened
      topic_archived
      topic_unarchived
      post_staff_note_create
      post_staff_note_destroy
      watched_word_create
      watched_word_destroy
      delete_group
      permanently_delete_post_revisions
      create_public_sidebar_section
      update_public_sidebar_section
      destroy_public_sidebar_section
      reset_bounce_score
      update_directory_columns
      deleted_unused_tags
      renamed_tag
      deleted_tag
      chat_channel_status_change
      chat_auto_remove_membership
      create_watched_word_group
      update_watched_word_group
      delete_watched_word_group
      topic_slow_mode_set
      topic_slow_mode_removed
      custom_emoji_create
      custom_emoji_destroy
      delete_post_permanently
      delete_topic_permanently
      tag_group_create
      tag_group_destroy
      tag_group_change
      delete_associated_accounts
      toggle_flag
      delete_flag
      update_flag
      create_flag
    ]
  end

  def self.staff_action_ids
    @staff_action_ids ||= staff_actions.map { |a| actions[a] }
  end

  def self.admin_only_action_ids
    @admin_only_action_ids ||= [actions[:change_site_setting]]
  end

  def self.with_filters(filters)
    query = self
    query = query.where(action: filters[:action_id]) if filters[:action_id].present?
    query = query.where(custom_type: filters[:custom_type]) if filters[:custom_type].present?

    %i[acting_user target_user].each do |key|
      if filters[key] && (obj_id = User.where(username_lower: filters[key].downcase).pluck(:id))
        query = query.where("#{key}_id = ?", obj_id)
      end
    end
    query = query.where("subject = ?", filters[:subject]) if filters[:subject]
    query
  end

  def self.for(user, action_type)
    self.where(target_user_id: user.id, action: UserHistory.actions[action_type])
  end

  def self.exists_for_user?(user, action_type, opts = nil)
    opts = opts || {}
    result = self.where(target_user_id: user.id, action: UserHistory.actions[action_type])
    result = result.where(topic_id: opts[:topic_id]) if opts[:topic_id]
    result.exists?
  end

  def self.staff_filters
    %i[action_id custom_type acting_user target_user subject action_name]
  end

  def self.staff_action_records(viewer, opts = nil)
    opts ||= {}
    custom_staff = opts[:action_id].to_i == actions[:custom_staff]

    if custom_staff
      opts[:custom_type] = opts[:action_name]
    else
      opts[:action_id] = self.actions[opts[:action_name].to_sym] if opts[:action_name]
    end

    query =
      self
        .with_filters(opts.slice(*staff_filters))
        .only_staff_actions
        .order("id DESC")
        .includes(:acting_user, :target_user)
    query = query.where(admin_only: false) unless viewer && viewer.admin?
    query
  end

  def set_admin_only
    self.admin_only = UserHistory.admin_only_action_ids.include?(self.action)
    self
  end

  def new_value_is_json?
    %i[change_theme delete_theme tag_group_create tag_group_destroy tag_group_change]
      .map { |i| UserHistory.actions[i] }
      .include?(action)
  end

  def previous_value_is_json?
    new_value_is_json?
  end
end

# == Schema Information
#
# Table name: user_histories
#
#  id             :integer          not null, primary key
#  action         :integer          not null
#  acting_user_id :integer
#  target_user_id :integer
#  details        :text
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  context        :string
#  ip_address     :string
#  email          :string
#  subject        :text
#  previous_value :text
#  new_value      :text
#  topic_id       :integer
#  admin_only     :boolean          default(FALSE)
#  post_id        :integer
#  custom_type    :string
#  category_id    :integer
#
# Indexes
#
#  index_user_histories_on_acting_user_id_and_action_and_id        (acting_user_id,action,id)
#  index_user_histories_on_action_and_id                           (action,id)
#  index_user_histories_on_category_id                             (category_id)
#  index_user_histories_on_post_id                                 (post_id)
#  index_user_histories_on_subject_and_id                          (subject,id)
#  index_user_histories_on_target_user_id_and_id                   (target_user_id,id)
#  index_user_histories_on_topic_id_and_target_user_id_and_action  (topic_id,target_user_id,action)
#
