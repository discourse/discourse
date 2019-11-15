# frozen_string_literal: true

require_dependency 'compression/zip'

module ThemeStore; end

class ThemeStore::ZipExporter

  def initialize(theme)
    @theme = theme
    @temp_folder = "#{Pathname.new(Dir.tmpdir).realpath}/discourse_theme_#{SecureRandom.hex}"
    @export_name = @theme.name.downcase.gsub(/[^0-9a-z.\-]/, '-')
    @export_name = "discourse-#{@export_name}" unless @export_name.starts_with?("discourse")
  end

  def export_name
    @export_name
  end

  def package_filename
    export_package
  end

  def cleanup!
    FileUtils.rm_rf(@temp_folder)
  end

  def export_to_folder
    destination_folder = File.join(@temp_folder, @export_name)
    FileUtils.mkdir_p(destination_folder)

    @theme.theme_fields.each do |field|
      next unless path = field.file_path

      # Belt and braces approach here. All the user input should already be
      # sanitized, but check for attempts to leave the temp directory anyway
      pathname = Pathname.new(File.join(destination_folder, path))
      folder_path = pathname.parent.cleanpath
      raise RuntimeError.new("Theme exporter tried to leave directory") unless folder_path.to_s.starts_with?(destination_folder)
      pathname.parent.mkpath
      path = pathname.realdirpath
      raise RuntimeError.new("Theme exporter tried to leave directory") unless path.to_s.starts_with?(destination_folder)

      if ThemeField.types[field.type_id] == :theme_upload_var
        filename = Discourse.store.path_for(field.upload)
        content = filename ? File.read(filename) : Discourse.store.download(field.upload).read
      else
        content = field.value
      end
      File.write(path, content)
    end

    File.write(File.join(destination_folder, "about.json"), JSON.pretty_generate(@theme.generate_metadata_hash))

    @temp_folder
  end

  private

  def export_package
    export_to_folder

    Compression::Zip.new.compress(@temp_folder, @export_name)
  end
end
