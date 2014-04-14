class PostUpload < ActiveRecord::Base
  belongs_to :post
  belongs_to :upload
end

# == Schema Information
#
# Table name: post_uploads
#
#  id        :integer          not null, primary key
#  post_id   :integer          not null
#  upload_id :integer          not null
#
# Indexes
#
#  idx_unique_post_uploads  (post_id,upload_id) UNIQUE
#
