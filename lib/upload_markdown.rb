# frozen_string_literal: true

class UploadMarkdown
  def initialize(upload)
    @upload = upload
  end

  def to_markdown(display_name: nil)
    if FileHelper.is_supported_image?(@upload.original_filename)
      image_markdown
    else
      attachment_markdown(display_name: display_name)
    end
  end

  def image_markdown
    "![#{@upload.original_filename}|#{@upload.width}x#{@upload.height}](#{@upload.short_url})"
  end

  def attachment_markdown(display_name: nil, with_filesize: true)
    human_filesize = with_filesize ? " (#{@upload.human_filesize})" : ""
    display_name ||= @upload.original_filename

    "[#{display_name}|attachment](#{@upload.short_url})#{human_filesize}"
  end
end
