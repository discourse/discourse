# frozen_string_literal: true

class UploadSerializer < ApplicationSerializer
  attributes :id,
             :url,
             :original_filename,
             :filesize,
             :width,
             :height,
             :thumbnail_width,
             :thumbnail_height,
             :extension,
             :short_url,
             :retain_hours,
             :human_filesize

  def url
    return object.url if !object.secure || !SiteSetting.secure_media?
    UrlHelper.cook_url(object.url, secure: object.secure)
  end
end
