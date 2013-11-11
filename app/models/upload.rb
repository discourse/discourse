require 'digest/sha1'
require 'image_sizer'
require 'tempfile'
require 'pathname'
require_dependency 's3_store'
require_dependency 'local_store'

class Upload < ActiveRecord::Base
  belongs_to :user

  has_many :post_uploads
  has_many :posts, through: :post_uploads

  has_many :optimized_images, dependent: :destroy

  validates_presence_of :filesize
  validates_presence_of :original_filename

  def thumbnail
    optimized_images.where(width: width, height: height).first
  end

  def thumbnail_url
    thumbnail.url if has_thumbnail?
  end

  def has_thumbnail?
    thumbnail.present?
  end

  def create_thumbnail!
    return unless SiteSetting.create_thumbnails?
    return if SiteSetting.enable_s3_uploads?
    return if has_thumbnail?
    thumbnail = OptimizedImage.create_for(self, width, height)
    optimized_images << thumbnail if thumbnail
  end

  def destroy
    Upload.transaction do
      Upload.remove_file url
      super
    end
  end

  def self.create_for(user_id, file, filesize)
    # compute the sha
    sha1 = Digest::SHA1.file(file.tempfile).hexdigest
    # check if the file has already been uploaded
    unless upload = Upload.where(sha1: sha1).first
      # deal with width & heights for images
      if SiteSetting.authorized_image?(file)
        # retrieve image info
        image_info = FastImage.new(file.tempfile, raise_on_failure: true)
        # compute image aspect ratio
        width, height = ImageSizer.resize(*image_info.size)
        # make sure we're at the beginning of the file (FastImage is moving the pointer)
        file.rewind
      end
      # create a db record (so we can use the id)
      upload = Upload.create!({
        user_id: user_id,
        original_filename: file.original_filename,
        filesize: filesize,
        sha1: sha1,
        url: "",
        width: width,
        height: height,
      })
      # store the file and update its url
      upload.url = Upload.store_file(file, sha1, upload.id)
      # save the url
      upload.save
    end
    # return the uploaded file
    upload
  end

  def self.store_file(file, sha1, upload_id)
    return S3Store.store_file(file, sha1, upload_id) if SiteSetting.enable_s3_uploads?
    return LocalStore.store_file(file, sha1, upload_id)
  end

  def self.remove_file(url)
    return S3Store.remove_file(url) if SiteSetting.enable_s3_uploads?
    return LocalStore.remove_file(url)
  end

  def self.has_been_uploaded?(url)
    is_relative?(url) || is_local?(url) || is_on_s3?(url)
  end

  def self.is_relative?(url)
    url.start_with?(LocalStore.directory)
  end

  def self.is_local?(url)
    !SiteSetting.enable_s3_uploads? && url.start_with?(LocalStore.base_url)
  end

  def self.is_on_s3?(url)
    SiteSetting.enable_s3_uploads? && url.start_with?(S3Store.base_url)
  end

  def self.get_from_url(url)
    # we store relative urls, so we need to remove any host/cdn
    url = url.gsub(/^#{LocalStore.asset_host}/i, "") if LocalStore.asset_host.present?
    Upload.where(url: url).first if has_been_uploaded?(url)
  end

end

# == Schema Information
#
# Table name: uploads
#
#  id                :integer          not null, primary key
#  user_id           :integer          not null
#  original_filename :string(255)      not null
#  filesize          :integer          not null
#  width             :integer
#  height            :integer
#  url               :string(255)      not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  sha1              :string(40)
#
# Indexes
#
#  index_uploads_on_sha1     (sha1) UNIQUE
#  index_uploads_on_url      (url)
#  index_uploads_on_user_id  (user_id)
#

