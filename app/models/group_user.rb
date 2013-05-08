class GroupUser < ActiveRecord::Base
  belongs_to :group, counter_cache: "user_count"
  belongs_to :user
end
