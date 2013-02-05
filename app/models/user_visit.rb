class UserVisit < ActiveRecord::Base
  attr_accessible :visited_at, :user_id
end
