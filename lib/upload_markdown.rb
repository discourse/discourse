# frozen_string_literal: true

class UploadMarkdown
  def initialize(upload)
    @upload = upload
  end

  def to_markdown(display_name: nil)
    if FileHelper.is_supported_image?(@upload.original_filename)
      image_markdown
    elsif FileHelper.is_supported_playable_media?(@upload.original_filename)
      playable_media_markdown
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

  def playable_media_markdown
    type =
      if FileHelper.is_supported_audio?(@upload.original_filename)
        "audio"
      elsif FileHelper.is_supported_video?(@upload.original_filename)
        "video"
      end
    return attachment_markdown if !type
    "![#{@upload.original_filename}|#{type}](#{@upload.short_url})"
  end
end
