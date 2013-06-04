require 'digest/sha1'
require 'image_sizer'
require 'imgur'
require 's3'
require 'local_store'

class Upload < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic

  validates_presence_of :filesize
  validates_presence_of :original_filename

  def self.create_for(user_id, file, topic_id)
    # retrieve image info
    image_info = FastImage.new(file.tempfile, raise_on_failure: true)
    # compute image aspect ratio
    width, height = ImageSizer.resize(*image_info.size)

    upload = Upload.create!({
      user_id: user_id,
      topic_id: topic_id,
      original_filename: file.original_filename,
      filesize: File.size(file.tempfile),
      width: width,
      height: height,
      url: ""
    })

    # make sure we're at the beginning of the file (FastImage is moving the pointer)
    file.rewind

    # store the file and update its url
    upload.url = Upload.store_file(file, image_info, upload.id)

    upload.save

    upload
  end

  def self.store_file(file, image_info, upload_id)
    return Imgur.store_file(file, image_info, upload_id) if SiteSetting.enable_imgur?
    return S3.store_file(file, image_info, upload_id)    if SiteSetting.enable_s3_uploads?
    return LocalStore.store_file(file, image_info, upload_id)
  end

end

# == Schema Information
#
# Table name: uploads
#
#  id                :integer          not null, primary key
#  user_id           :integer          not null
#  topic_id          :integer          not null
#  original_filename :string(255)      not null
#  filesize          :integer          not null
#  width             :integer
#  height            :integer
#  url               :string(255)      not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_uploads_on_forum_thread_id  (topic_id)
#  index_uploads_on_user_id          (user_id)
#
