# frozen_string_literal: true

class UserExportSerializer < ApplicationSerializer
  attributes :id, :filename, :uri, :filesize, :extension, :retain_hours, :human_filesize

  def serializable_hash(adapter_options = nil, options = {})
    return {} unless object.upload
    super()
  end

  def filename
    object.upload.original_filename
  end

  def uri
    object.upload.short_path
  end

  def filesize
    object.upload.filesize
  end

  def extension
    object.upload.extension
  end

  def human_filesize
    object.upload.human_filesize
  end
end
