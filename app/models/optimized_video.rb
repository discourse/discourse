# frozen_string_literal: true

class OptimizedVideo < ActiveRecord::Base
  include HasUrl
  belongs_to :upload

  def self.create_for(upload, filename, user_id, options = {})
    return if upload.blank?

    optimized_video =
      OptimizedVideo.new(
        upload_id: upload.id,
        sha1: options[:sha1],
        extension: options[:extension] || File.extname(filename),
        url: options[:url],
        filesize: options[:filesize],
      )

    if optimized_video.save
      optimized_video
    else
      Rails.logger.error(
        "Failed to create optimized video: #{optimized_video.errors.full_messages.join(", ")}",
      )
      nil
    end
  end
end

# == Schema Information
#
# Table name: optimized_videos
#
#  id         :bigint           not null, primary key
#  sha1       :string
#  extension  :string
#  upload_id  :integer
#  url        :string
#  filesize   :integer
#  etag       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
