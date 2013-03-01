class UserOpenId < ActiveRecord::Base
  belongs_to :user
  attr_accessible :email, :url, :user_id, :active

  validates_presence_of :email
  validates_presence_of :url
end
