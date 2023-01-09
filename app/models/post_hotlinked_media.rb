# frozen_string_literal: true

class PostHotlinkedMedia < ActiveRecord::Base
  belongs_to :post
  belongs_to :upload
  enum status: {
         downloaded: "downloaded",
         too_large: "too_large",
         download_failed: "download_failed",
         upload_create_failed: "upload_create_failed",
       }

  def self.normalize_src(src)
    uri = Addressable::URI.heuristic_parse(src)
    uri.normalize!
    uri.scheme = nil
    uri.to_s
  rescue URI::Error, Addressable::URI::InvalidURIError
    src
  end
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
#  index_post_hotlinked_media_on_post_id_and_url_md5  (post_id, md5((url)::text)) UNIQUE
#
