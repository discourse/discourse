# AdminLog stores information about actions that admins and moderators have taken,
# like deleting users, changing site settings, etc.
# Use the AdminLogger class to log records to this table.
class AdminLog < ActiveRecord::Base
  attr_accessible :action, :admin_id, :target_user_id, :details

  belongs_to :admin,        class_name: 'User'
  belongs_to :target_user,  class_name: 'User' # can be nil

  validates_presence_of :admin_id
  validates_presence_of :action

  def self.actions
    @actions ||= Enum.new(:delete_user)
  end
end
