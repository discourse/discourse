# AdminLog stores information about actions that admins and moderators have taken,
# like deleting users, changing site settings, etc.
# Use the AdminLogger class to log records to this table.
class AdminLog < ActiveRecord::Base
  belongs_to :admin,        class_name: 'User'
  belongs_to :target_user,  class_name: 'User' # can be nil, or return nil if user record was nuked

  validates_presence_of :admin_id
  validates_presence_of :action

  def self.actions
    @actions ||= Enum.new(:delete_user, :change_trust_level)
  end
end

# == Schema Information
#
# Table name: admin_logs
#
#  id             :integer          not null, primary key
#  action         :integer          not null
#  admin_id       :integer          not null
#  target_user_id :integer
#  details        :text
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#

