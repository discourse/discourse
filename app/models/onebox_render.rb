class OneboxRender < ActiveRecord::Base
  validates_presence_of :url
  validates_presence_of :cooked
  validates_presence_of :expires_at

  has_many :post_onebox_renders, dependent: :delete_all
  has_many :posts, through: :post_onebox_renders
end
