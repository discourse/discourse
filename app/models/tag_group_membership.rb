class TagGroupMembership < ActiveRecord::Base
  belongs_to :tag
  belongs_to :tag_group, counter_cache: "tag_count"
end
