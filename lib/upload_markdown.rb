# frozen_string_literal: true

class UploadMarkdown
  def initialize(upload)
    @upload = upload
  end

  def to_markdown(display_name: nil)
    if FileHelper.is_supported_image?(@upload.original_filename)
      image_markdown(display_name: display_name)
    elsif FileHelper.is_supported_playable_media?(@upload.original_filename)
      playable_media_markdown(display_name: display_name)
    else
      attachment_markdown(display_name: display_name)
    end
  end

  def image_markdown(display_name: nil)
    "![#{display_label(display_name)}|#{@upload.width}x#{@upload.height}](#{@upload.short_url})"
  end

  def attachment_markdown(display_name: nil, with_filesize: true)
    human_filesize = with_filesize ? " (#{@upload.human_filesize})" : ""
    "[#{display_label(display_name)}|attachment](#{@upload.short_url})#{human_filesize}"
  end

  def playable_media_markdown(display_name: nil)
    type =
      if FileHelper.is_supported_audio?(@upload.original_filename)
        "audio"
      elsif FileHelper.is_supported_video?(@upload.original_filename)
        "video"
      end
    return attachment_markdown if !type
    "![#{display_label(display_name)}|#{type}](#{@upload.short_url})"
  end

  private

  # `[`, `]` and `|` would break the link/image syntax, and escaping them would
  # reintroduce the rich-editor backslash doubling this whole change removes, so
  # strip them from the label instead.
  def display_label(display_name)
    (display_name || @upload.original_filename).to_s.gsub(/[\[\]\|]/, "")
  end
end
