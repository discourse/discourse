require 'digest/sha1'
require 'image_sizer'
require 'tempfile'
require 'pathname'

class Upload < ActiveRecord::Base
  belongs_to :user

  has_many :post_uploads
  has_many :posts, through: :post_uploads

  has_many :optimized_images, dependent: :destroy

  validates_presence_of :filesize
  validates_presence_of :original_filename

  def thumbnail(width = nil, height = nil)
    width ||= self.width
    height ||= self.height
    optimized_images.where(width: width, height: height).first
  end

  def has_thumbnail?(width = nil, height = nil)
    thumbnail(width, height).present?
  end

  def create_thumbnail!(width, height)
    return unless SiteSetting.create_thumbnails?
    return if has_thumbnail?(width, height)
    thumbnail = OptimizedImage.create_for(self, width, height)
    if thumbnail
      optimized_images << thumbnail
      self.width = width
      self.height = height
      save!
    end
  end

  def destroy
    Upload.transaction do
      Discourse.store.remove_upload(self)
      super
    end
  end

  def extension
    File.extname(original_filename)
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
      upload = Upload.create!(
        user_id: user_id,
        original_filename: file.original_filename,
        filesize: filesize,
        sha1: sha1,
        url: "",
        width: width,
        height: height,
      )
      # store the file and update its url
      upload.url = Discourse.store.store_upload(file, upload)
      # save the url
      upload.save
    end
    # return the uploaded file
    upload
  end

  def self.get_from_url(url)
    # we store relative urls, so we need to remove any host/cdn
    asset_host = Rails.configuration.action_controller.asset_host
    url = url.gsub(/^#{asset_host}/i, "") if asset_host.present?
    Upload.where(url: url).first if Discourse.store.has_been_uploaded?(url)
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
#  index_uploads_on_id_and_url  (id,url)
#  index_uploads_on_sha1        (sha1) UNIQUE
#  index_uploads_on_url         (url)
#  index_uploads_on_user_id     (user_id)
#

