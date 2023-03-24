# frozen_string_literal: true

# This model indicates an 'attempt' to create a topic thumbnail
# for an upload. This means we don't keep trying to create optimized
# images for small/invalid original images.
#
# Foreign keys with ON DELETE CASCADE are used to ensure unneeded data
# is deleted automatically
class TopicThumbnail < ActiveRecord::Base
  belongs_to :upload
  belongs_to :optimized_image

  def self.find_or_create_for!(original, max_width:, max_height:)
    existing =
      TopicThumbnail.find_by(upload: original, max_width: max_width, max_height: max_height)
    return existing if existing
    return nil if !SiteSetting.create_thumbnails?

    target_width, target_height =
      ImageSizer.resize(
        original.width,
        original.height,
        { max_width: max_width, max_height: max_height },
      )

    if target_width < original.width && target_height < original.height
      optimized = OptimizedImage.create_for(original, target_width, target_height)
    end

    # may have been associated already, bulk insert will skip dupes
    TopicThumbnail.insert_all(
      [
        upload_id: original.id,
        max_width: max_width,
        max_height: max_height,
        optimized_image_id: optimized&.id,
      ],
    )

    TopicThumbnail.find_by(upload: original, max_width: max_width, max_height: max_height)
  end

  def self.ensure_consistency!
    # Clean up records for broken upload links or broken optimized image links
    TopicThumbnail
      .joins("LEFT JOIN uploads on upload_id = uploads.id")
      .joins("LEFT JOIN optimized_images on optimized_image_id = optimized_images.id")
      .where(<<~SQL)
        (optimized_image_id IS NOT NULL AND optimized_images IS NULL)
        OR uploads IS NULL
      SQL
      .delete_all

    # Delete records for sizes which are no longer needed
    sizes =
      Topic.thumbnail_sizes +
        ThemeModifierHelper.new(theme_ids: Theme.pluck(:id)).topic_thumbnail_sizes
    sizes_sql =
      sizes.map { |s| "(max_width = #{s[0].to_i} AND max_height = #{s[1].to_i})" }.join(" OR ")
    TopicThumbnail.where.not(sizes_sql).delete_all
  end
end

# == Schema Information
#
# Table name: topic_thumbnails
#
#  id                 :bigint           not null, primary key
#  upload_id          :bigint           not null
#  optimized_image_id :bigint
#  max_width          :integer          not null
#  max_height         :integer          not null
#
# Indexes
#
#  index_topic_thumbnails_on_optimized_image_id  (optimized_image_id)
#  index_topic_thumbnails_on_upload_id           (upload_id)
#  unique_topic_thumbnails                       (upload_id,max_width,max_height) UNIQUE
#
