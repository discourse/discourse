class ClefUserInfo < ActiveRecord::Base
  attr_accessible :email, :clef_user_id, :first_name, :last_name, :name, :user_id
  belongs_to :user
end
