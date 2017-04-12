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

  scope :only_staff_actions, ->{ where("action IN (?)", UserHistory.staff_action_ids) }

  before_save :set_admin_only

  def self.actions
    @actions ||= Enum.new(delete_user: 1,
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
                          facebook_no_email: 12,
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
                          block_user: 30,
                          unblock_user: 31,
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
                          change_name: 48)
  end

  # Staff actions is a subset of all actions, used to audit actions taken by staff users.
  def self.staff_actions
    @staff_actions ||= [:delete_user,
                        :change_trust_level,
                        :change_site_setting,
                        :change_theme,
                        :delete_theme,
                        :change_site_text,
                        :suspend_user,
                        :unsuspend_user,
                        :grant_badge,
                        :revoke_badge,
                        :check_email,
                        :delete_post,
                        :delete_topic,
                        :impersonate,
                        :roll_up,
                        :change_username,
                        :custom_staff,
                        :anonymize_user,
                        :reviewed_post,
                        :change_category_settings,
                        :delete_category,
                        :create_category,
                        :block_user,
                        :unblock_user,
                        :grant_admin,
                        :revoke_admin,
                        :grant_moderation,
                        :revoke_moderation,
                        :backup_create,
                        :revoke_email,
                        :deactivate_user,
                        :lock_trust_level,
                        :unlock_trust_level,
                        :activate_user,
                        :change_readonly_mode,
                        :backup_download,
                        :backup_destroy]
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

    [:acting_user, :target_user].each do |key|
      if filters[key] and obj_id = User.where(username_lower: filters[key].downcase).pluck(:id)
        query = query.where("#{key}_id = ?", obj_id)
      end
    end
    query = query.where("subject = ?", filters[:subject]) if filters[:subject]
    query
  end

  def self.for(user, action_type)
    self.where(target_user_id: user.id, action: UserHistory.actions[action_type])
  end

  def self.exists_for_user?(user, action_type, opts=nil)
    opts = opts || {}
    result = self.where(target_user_id: user.id, action: UserHistory.actions[action_type])
    result = result.where(topic_id: opts[:topic_id]) if opts[:topic_id]
    result.exists?
  end

  def self.staff_filters
    [:action_id, :custom_type, :acting_user, :target_user, :subject]
  end

  def self.staff_action_records(viewer, opts=nil)
    opts ||= {}
    query = self.with_filters(opts.slice(*staff_filters)).only_staff_actions.limit(200).order('id DESC').includes(:acting_user, :target_user)
    query = query.where(admin_only: false) unless viewer && viewer.admin?
    query
  end


  def set_admin_only
    self.admin_only = UserHistory.admin_only_action_ids.include?(self.action)
    self
  end

  def new_value_is_json?
    [UserHistory.actions[:change_theme], UserHistory.actions[:delete_theme]].include?(action)
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
#  index_user_histories_on_acting_user_id_and_action_and_id  (acting_user_id,action,id)
#  index_user_histories_on_action_and_id                     (action,id)
#  index_user_histories_on_category_id                       (category_id)
#  index_user_histories_on_subject_and_id                    (subject,id)
#  index_user_histories_on_target_user_id_and_id             (target_user_id,id)
#
