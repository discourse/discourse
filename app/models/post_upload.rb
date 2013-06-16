class PostUpload < ActiveRecord::Base
  belongs_to :post
  belongs_to :upload
end
