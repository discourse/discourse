# frozen_string_literal: true

class OptimizedVideoSerializer < ApplicationSerializer
  attributes :id, :upload_id, :url, :extension, :filesize, :sha1

  def url
    if object.optimized_upload
      UrlHelper.cook_url(
        object.optimized_upload.url,
        secure: SiteSetting.secure_uploads? && object.optimized_upload.secure,
      )
    end
  end
end
