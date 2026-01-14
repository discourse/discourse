# frozen_string_literal: true

class OptimizedVideo < ActiveRecord::Base
  belongs_to :upload
  belongs_to :optimized_upload, class_name: "Upload"

  validates :upload_id, presence: true
  validates :optimized_upload_id, presence: true
  validates :adapter, presence: true
  validates :upload_id, uniqueness: { scope: :adapter }

  def self.create_for(upload, filename, user_id, options = {})
    return if upload.blank?

    optimized_upload =
      Upload.create!(
        user_id: user_id,
        original_filename: filename,
        filesize: options[:filesize],
        sha1: options[:sha1],
        extension: options[:extension] || "mp4",
        url: options[:url],
        etag: options[:etag],
        skip_video_conversion: true,
        secure: upload.secure?,
      )

    optimized_video =
      OptimizedVideo.new(
        upload_id: upload.id,
        optimized_upload_id: optimized_upload.id,
        adapter: options[:adapter],
      )

    if optimized_video.save
      UploadReference.ensure_exist!(upload_ids: [optimized_upload.id], target: upload)
      optimized_video
    else
      optimized_upload.destroy
      Rails.logger.error(
        "Failed to create optimized video for upload ID #{upload.id}: #{optimized_video.errors.full_messages.join(", ")}",
      )
      nil
    end
  end

  def destroy
    OptimizedVideo.transaction do
      Discourse.store.remove_upload(optimized_upload) if optimized_upload
      if optimized_upload_id
        UploadReference.where(upload_id: optimized_upload_id, target: upload).destroy_all
      end
      super
      optimized_upload&.destroy
    end
  end

  delegate :url, :filesize, :sha1, :extension, to: :optimized_upload
end

# == Schema Information
#
# Table name: optimized_videos
#
#  id                  :bigint           not null, primary key
#  upload_id           :integer          not null
#  optimized_upload_id :integer          not null
#  adapter             :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_optimized_videos_on_optimized_upload_id    (optimized_upload_id)
#  index_optimized_videos_on_upload_id              (upload_id)
#  index_optimized_videos_on_upload_id_and_adapter  (upload_id,adapter) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (optimized_upload_id => uploads.id)
#  fk_rails_...  (upload_id => uploads.id)
#
