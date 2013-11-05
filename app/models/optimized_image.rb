require "digest/sha1"

class OptimizedImage < ActiveRecord::Base
  belongs_to :upload

  def self.create_for(upload, width, height)
    return unless width > 0 && height > 0

    # do we already have that thumbnail?
    thumbnail = where(upload_id: upload.id, width: width, height: height).first

    # make sure the previous thumbnail has not failed
    if thumbnail && thumbnail.url.blank?
      thumbnail.destroy
      thumbnail = nil
    end

    # create the thumbnail otherwise
    unless thumbnail
      @image_sorcery_loaded ||= require "image_sorcery"

      external_copy = Discourse.store.download(upload) if Discourse.store.external?
      original_path = if Discourse.store.external?
        external_copy.path
      else
        Discourse.store.path_for(upload)
      end

      # create a temp file with the same extension as the original
      extension = File.extname(original_path)
      temp_file = Tempfile.new(["discourse-thumbnail", extension])
      temp_path = temp_file.path

      if ImageSorcery.new("#{original_path}[0]").convert(temp_path, resize: "#{width}x#{height}!")
        thumbnail = OptimizedImage.create!(
          upload_id: upload.id,
          sha1: Digest::SHA1.file(temp_path).hexdigest,
          extension: File.extname(temp_path),
          width: width,
          height: height,
          url: "",
        )
        # store the optimized image and update its url
        url = Discourse.store.store_optimized_image(temp_file, thumbnail)
        if url.present?
          thumbnail.url = url
          thumbnail.save
        else
          Rails.logger.error("Failed to store avatar #{size} for #{upload.url} from #{source}")
        end
      else
        Rails.logger.error("Failed to create optimized image #{width}x#{height} for #{upload.url}")
      end

      # close && remove temp file
      temp_file.close!
      # make sure we remove the cached copy from external stores
      external_copy.close! if Discourse.store.external?
    end

    thumbnail
  end

  def destroy
    OptimizedImage.transaction do
      Discourse.store.remove_optimized_image(self)
      super
    end
  end

end

# == Schema Information
#
# Table name: optimized_images
#
#  id        :integer          not null, primary key
#  sha1      :string(40)       not null
#  extension :string(10)       not null
#  width     :integer          not null
#  height    :integer          not null
#  upload_id :integer          not null
#  url       :string(255)      not null
#
# Indexes
#
#  index_optimized_images_on_upload_id                       (upload_id)
#  index_optimized_images_on_upload_id_and_width_and_height  (upload_id,width,height) UNIQUE
#

