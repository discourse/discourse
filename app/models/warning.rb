class Warning < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic
  belongs_to :created_by, class_name: 'User'
end
