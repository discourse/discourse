class FacebookUserInfo < ActiveRecord::Base
  attr_accessible :email, :facebook_user_id, :first_name, :gender, :last_name, :name, :user_id, :username, :link
  belongs_to :user
end
