# frozen_string_literal: true

class UploadFixer
  def self.fix_all_extensions
    Upload.where("uploads.extension IS NOT NULL").find_each do |upload|
      fix_extension_on_upload(upload)
    end
  end

  def self.fix_extension_on_upload(upload)
    is_external = Discourse.store.external?
    previous_url = upload.url.dup

    source =
      if is_external
        "https:#{previous_url}"
      else
        Discourse.store.path_for(upload)
      end

    correct_extension = FastImage.type(source).to_s.downcase
    current_extension = upload.extension.to_s.downcase

    if correct_extension.present?
      correct_extension = 'jpg' if correct_extension == 'jpeg'
      current_extension = 'jpg' if current_extension == 'jpeg'

      if correct_extension != current_extension
        new_filename = change_extension(
          upload.original_filename,
          correct_extension
        )

        new_url = change_extension(previous_url, correct_extension)

        if is_external
          new_url = "/#{new_url}"
          source = Discourse.store.get_path_for_upload(upload)
          destination = change_extension(source, correct_extension)

          Discourse.store.copy_file(
            previous_url,
            source,
            destination
          )

          upload.update!(
            original_filename: new_filename,
            url: new_url,
            extension: correct_extension
          )

          DbHelper.remap(previous_url, upload.url)
          Discourse.store.remove_file(previous_url, source)
        else
          destination = change_extension(source, correct_extension)
          FileUtils.copy(source, destination)

          upload.update!(
            original_filename: new_filename,
            url: new_url,
            extension: correct_extension
          )

          DbHelper.remap(previous_url, upload.url)

          tombstone_path = source.sub("/uploads/", "/uploads/tombstone/")
          FileUtils.mkdir_p(File.dirname(tombstone_path))

          FileUtils.move(
            source,
            tombstone_path
          )
        end

      end
    end
  rescue => e
    STDERR.puts "Skipping upload: failed to correct extension on upload id: #{upload.id} #{current_extension} => #{correct_extension}"
    STDERR.puts e
  end

  private

  def self.change_extension(path, extension)
    pathname = Pathname.new(path)
    dirname = pathname.dirname.to_s != "." ? "#{pathname.dirname}/" : ""
    basename = File.basename(path, File.extname(path))
    "#{dirname}#{basename}.#{extension}"
  end
end
