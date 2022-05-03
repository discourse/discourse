# frozen_string_literal: true

class PostHotlinkedMedia < ActiveRecord::Base
  belongs_to :post
  belongs_to :upload
  enum status: {
    downloaded: "downloaded",
    too_large: "too_large",
    download_failed: "download_failed",
    upload_create_failed: "upload_create_failed"
  }
end

# == Schema Information
#
# Table name: post_hotlinked_media
#
#  id         :bigint           not null, primary key
#  post_id    :bigint           not null
#  url        :string           not null
#  status     :enum             not null
#  upload_id  :bigint
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_post_hotlinked_media_on_post_id_and_url  (post_id,url) UNIQUE
#
