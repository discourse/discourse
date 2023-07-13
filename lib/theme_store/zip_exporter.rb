# frozen_string_literal: true

require "compression/zip"

module ThemeStore
end

class ThemeStore::ZipExporter
  def initialize(theme)
    @theme = theme
    @temp_folder = "#{Pathname.new(Dir.tmpdir).realpath}/discourse_theme_#{SecureRandom.hex}"
    @export_name = @theme.name.downcase.gsub(/[^0-9a-z.\-]/, "-")
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

  def with_export_dir(**kwargs)
    export_to_folder(**kwargs)

    yield File.join(@temp_folder, @export_name)
  ensure
    cleanup!
  end

  private

  def export_to_folder(extra_scss_only: false)
    destination_folder = File.join(@temp_folder, @export_name)
    FileUtils.mkdir_p(destination_folder)

    @theme.theme_fields.each do |field|
      next if extra_scss_only && !field.extra_scss_field?
      next unless path = field.file_path

      # Belt and braces approach here. All the user input should already be
      # sanitized, but check for attempts to leave the temp directory anyway
      pathname = Pathname.new(File.join(destination_folder, path))
      folder_path = pathname.parent.cleanpath
      unless folder_path.to_s.starts_with?(destination_folder)
        raise RuntimeError.new("Theme exporter tried to leave directory")
      end
      pathname.parent.mkpath
      path = pathname.realdirpath
      unless path.to_s.starts_with?(destination_folder)
        raise RuntimeError.new("Theme exporter tried to leave directory")
      end

      if ThemeField.types[field.type_id] == :theme_upload_var
        content = field.upload.content
      else
        content = field.value
      end
      File.write(path, content)
    end

    if !extra_scss_only
      File.write(
        File.join(destination_folder, "about.json"),
        JSON.pretty_generate(@theme.generate_metadata_hash),
      )
    end

    @temp_folder
  end

  def export_package
    export_to_folder

    Compression::Zip.new.compress(@temp_folder, @export_name)
  end
end
