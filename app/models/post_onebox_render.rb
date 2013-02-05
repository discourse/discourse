class PostOneboxRender < ActiveRecord::Base
  belongs_to :post
  belongs_to :onebox_render

  validates_uniqueness_of :post_id, scope: :onebox_render_id
end
