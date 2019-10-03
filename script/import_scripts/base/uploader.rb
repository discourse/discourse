# frozen_string_literal: true

module ImportScripts
  class Uploader
    # Creates an upload.
    # Expects path to be the full path and filename of the source file.
    # @return [Upload]
    def create_upload(user_id, path, source_filename)
      tmp = copy_to_tempfile(path)

      UploadCreator.new(tmp, source_filename).create_for(user_id)
    rescue => e
      STDERR.puts "Failed to create upload: #{e}"
      nil
    ensure
      tmp.close rescue nil
      tmp.unlink rescue nil
    end

    def create_avatar(user, avatar_path)
      tempfile = copy_to_tempfile(avatar_path)
      filename = "avatar#{File.extname(avatar_path)}"
      upload = UploadCreator.new(tempfile, filename, type: "avatar").create_for(user.id)

      if upload.present? && upload.persisted?
        user.create_user_avatar
        user.user_avatar.update(custom_upload_id: upload.id)
        user.update(uploaded_avatar_id: upload.id)
      else
        STDERR.puts "Failed to upload avatar for user #{user.username}: #{avatar_path}"
        STDERR.puts upload.errors.inspect if upload
      end
    rescue
      STDERR.puts "Failed to create avatar for user #{user.username}: #{avatar_path}"
    ensure
      tempfile.close! if tempfile
    end

    def html_for_upload(upload, display_filename)
      UploadMarkdown.new(upload).to_markdown(display_name: display_filename)
    end

    def embedded_image_html(upload)
      UploadMarkdown.new(upload).image_markdown
    end

    def attachment_html(upload, display_filename)
      UploadMarkdown.new(upload).attachment_markdown(display_name: display_filename)
    end

    private

    def copy_to_tempfile(source_path)
      extension = File.extname(source_path)
      tmp = Tempfile.new(['discourse-upload', extension])

      File.open(source_path) do |source_stream|
        IO.copy_stream(source_stream, tmp)
      end

      tmp.rewind
      tmp
    end
  end
end
