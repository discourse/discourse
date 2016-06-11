class TagGroupMembership < ActiveRecord::Base
  belongs_to :tag
  belongs_to :tag_group
end
