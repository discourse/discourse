require_dependency 'url_helper'
require_dependency 'file_helper'

module ImportScripts
  class Uploader
    include ActionView::Helpers::NumberHelper

    # Creates an upload.
    # Expects path to be the full path and filename of the source file.
    # @return [Upload]
    def create_upload(user_id, path, source_filename)
      tmp = Tempfile.new('discourse-upload')
      src = File.open(path)
      FileUtils.copy_stream(src, tmp)
      src.close
      tmp.rewind

      Upload.create_for(user_id, tmp, source_filename, tmp.size)
    rescue => e
      Rails.logger.error("Failed to create upload: #{e}")
      nil
    ensure
      tmp.close rescue nil
      tmp.unlink rescue nil
    end

    def html_for_upload(upload, display_filename)
      if FileHelper.is_image?(upload.url)
        embedded_image_html(upload)
      else
        attachment_html(upload, display_filename)
      end
    end

    def embedded_image_html(upload)
      image_width = [upload.width, SiteSetting.max_image_width].compact.min
      image_height = [upload.height, SiteSetting.max_image_height].compact.min
      %Q[<img src="#{upload.url}" width="#{image_width}" height="#{image_height}"><br/>]
    end

    def attachment_html(upload, display_filename)
      "<a class='attachment' href='#{upload.url}'>#{display_filename}</a> (#{number_to_human_size(upload.filesize)})"
    end
  end
end
