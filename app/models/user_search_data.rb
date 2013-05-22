class UserSearchData < ActiveRecord::Base
  belongs_to :user
  validates_presence_of :search_data
end
