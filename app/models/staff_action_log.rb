# StaffActionLog stores information about actions that staff members have taken,
# like deleting users, changing site settings, etc.
# Use the StaffActionLogger class to log records to this table.
class StaffActionLog < ActiveRecord::Base
  belongs_to :staff_user,   class_name: 'User'
  belongs_to :target_user,  class_name: 'User'

  validates_presence_of :staff_user_id
  validates_presence_of :action

  def self.actions
    @actions ||= Enum.new(:delete_user, :change_trust_level)
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
    query
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
#

