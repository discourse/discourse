# UserHistory stores information about actions that users have taken,
# like deleting users, changing site settings, dimissing notifications, etc.
# Use other classes, like StaffActionLogger, to log records to this table.
class UserHistory < ActiveRecord::Base
  belongs_to :acting_user, class_name: 'User'
  belongs_to :target_user, class_name: 'User'

  belongs_to :post
  belongs_to :topic
  belongs_to :category

  validates_presence_of :action

  scope :only_staff_actions,
        -> { where('action IN (?)', UserHistory.staff_action_ids) }

  before_save :set_admin_only

  def self.actions
    @actions ||= Enum.new
  end

  # Staff actions is a subset of all actions, used to audit actions taken by staff users.
  def self.staff_actions
    @staff_actions ||=
      %i[
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
    if filters[:action_id].present?
      query = query.where(action: filters[:action_id])
    end
    if filters[:custom_type].present?
      query = query.where(custom_type: filters[:custom_type])
    end

    %i[acting_user target_user].each do |key|
      if filters[key] &&
         (obj_id = User.where(username_lower: filters[key].downcase).pluck(:id))
        query = query.where("#{key}_id = ?", obj_id)
      end
    end
    query = query.where('subject = ?', filters[:subject]) if filters[:subject]
    query
  end

  def self.for(user, action_type)
    self.where(
      target_user_id: user.id, action: UserHistory.actions[action_type]
    )
  end

  def self.exists_for_user?(user, action_type, opts = nil)
    opts = opts || {}
    result =
      self.where(
        target_user_id: user.id, action: UserHistory.actions[action_type]
      )
    result = result.where(topic_id: opts[:topic_id]) if opts[:topic_id]
    result.exists?
  end

  def self.staff_filters
    %i[action_id custom_type acting_user target_user subject]
  end

  def self.staff_action_records(viewer, opts = nil)
    opts ||= {}
    query =
      self.with_filters(opts.slice(*staff_filters)).only_staff_actions.limit(
        200
      )
        .order('id DESC')
        .includes(:acting_user, :target_user)
    query = query.where(admin_only: false) unless viewer && viewer.admin?
    query
  end

  def set_admin_only
    self.admin_only = UserHistory.admin_only_action_ids.include?(self.action)
    self
  end

  def new_value_is_json?
    [UserHistory.actions[:change_theme], UserHistory.actions[:delete_theme]]
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
#  index_user_histories_on_subject_and_id                          (subject,id)
#  index_user_histories_on_target_user_id_and_id                   (target_user_id,id)
#  index_user_histories_on_topic_id_and_target_user_id_and_action  (topic_id,target_user_id,action)
#
