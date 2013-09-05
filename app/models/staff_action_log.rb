# StaffActionLog stores information about actions that staff members have taken,
# like deleting users, changing site settings, etc.
# Use the StaffActionLogger class to log records to this table.
class StaffActionLog < ActiveRecord::Base
  belongs_to :staff_user,   class_name: 'User'
  belongs_to :target_user,  class_name: 'User'

  validates_presence_of :staff_user_id
  validates_presence_of :action

  def self.actions
    @actions ||= Enum.new( :delete_user,
                           :change_trust_level,
                           :change_site_setting,
                           :change_site_customization,
                           :delete_site_customization)
  end

  def self.with_filters(filters)
    query = self
    if filters[:action_name] and action_id = StaffActionLog.actions[filters[:action_name].to_sym]
      query = query.where('action = ?', action_id)
    end
    [:staff_user, :target_user].each do |key|
      if filters[key] and obj_id = User.where(username_lower: filters[key].downcase).pluck(:id)
        query = query.where("#{key.to_s}_id = ?", obj_id)
      end
    end
    query = query.where("subject = ?", filters[:subject]) if filters[:subject]
    query
  end

  def new_value_is_json?
    [StaffActionLog.actions[:change_site_customization], StaffActionLog.actions[:delete_site_customization]].include?(action)
  end

  def previous_value_is_json?
    new_value_is_json?
  end
end

# == Schema Information
#
# Table name: staff_action_logs
#
#  id             :integer          not null, primary key
#  action         :integer          not null
#  staff_user_id  :integer          not null
#  target_user_id :integer
#  details        :text
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  context        :string(255)
#  ip_address     :string(255)
#  email          :string(255)
#  subject        :text
#  previous_value :text
#  new_value      :text
#
# Indexes
#
#  index_staff_action_logs_on_action_and_id          (action,id)
#  index_staff_action_logs_on_staff_user_id_and_id   (staff_user_id,id)
#  index_staff_action_logs_on_subject_and_id         (subject,id)
#  index_staff_action_logs_on_target_user_id_and_id  (target_user_id,id)
#

