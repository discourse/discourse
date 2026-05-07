# frozen_string_literal: true

class CategoryUploadSerializer < ApplicationSerializer
  attributes :id, :url, :width, :height

  def url
    UrlHelper.cook_url(object.url, secure: SiteSetting.secure_uploads? && object.secure?)
  end
end
