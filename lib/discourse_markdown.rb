# frozen_string_literal: true

require_dependency "file_helper"

class DiscourseMarkdown
  def self.upload_markdown(upload, display_name: nil)
    if FileHelper.is_supported_image?(upload.original_filename)
      image_markdown(upload)
    else
      attachment_markdown(upload, display_name: display_name)
    end
  end

  def self.image_markdown(upload)
    "![#{upload.original_filename}|#{upload.width}x#{upload.height}](#{upload.short_url})"
  end

  def self.attachment_markdown(upload, display_name: nil, with_filesize: true)
    human_filesize = with_filesize ? " (#{upload.human_filesize})" : ""
    display_name ||= upload.original_filename

    "[#{display_name}|attachment](#{upload.short_url})#{human_filesize}"
  end
end
