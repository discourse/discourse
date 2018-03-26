# Who can see and use tags belonging to a tag group.
class TagGroupPermission < ActiveRecord::Base
  belongs_to :tag_group
  belongs_to :group

  def self.permission_types
    @permission_types ||= Enum.new(full: 1) #, see: 2
  end
end
