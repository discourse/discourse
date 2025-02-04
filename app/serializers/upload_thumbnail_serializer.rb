# frozen_string_literal: true

class UploadThumbnailSerializer < ApplicationSerializer
  attributes :id, :upload_id, :width, :height, :url, :extension, :filesize
end
