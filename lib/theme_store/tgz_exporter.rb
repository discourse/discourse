# frozen_string_literal: true

module ThemeStore; end

class ThemeStore::TgzExporter

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
    FileUtils.mkdir(@temp_folder)

    Dir.chdir(@temp_folder) do
      FileUtils.mkdir(@export_name)

      @theme.theme_fields.each do |field|
        next unless path = field.file_path

        # Belt and braces approach here. All the user input should already be
        # sanitized, but check for attempts to leave the temp directory anyway
        pathname = Pathname.new("#{@export_name}/#{path}")
        folder_path = pathname.parent.cleanpath
        raise RuntimeError.new("Theme exporter tried to leave directory") unless folder_path.to_s.starts_with?("#{@export_name}")
        pathname.parent.mkpath
        path = pathname.realdirpath
        raise RuntimeError.new("Theme exporter tried to leave directory") unless path.to_s.starts_with?("#{@temp_folder}/#{@export_name}")

        if ThemeField.types[field.type_id] == :theme_upload_var
          if Discourse.store.local?(field.upload)
            filename = Discourse.store.path_for(field.upload)
            content = File.read(filename)
          else
            content = Discourse.store.download(field.upload).read
          end
        else
          content = field.value
        end
        File.write(path, content)
      end

      File.write("#{@export_name}/about.json", JSON.pretty_generate(@theme.generate_metadata_hash))
    end
    @temp_folder
  end

  private
  def export_package
    export_to_folder
    Dir.chdir(@temp_folder) do
      tar_filename = "#{@export_name}.tar"
      Discourse::Utils.execute_command('tar', '--create', '--file', tar_filename, @export_name, failure_message: "Failed to tar theme.")
      Discourse::Utils.execute_command('gzip', '-5', tar_filename, failure_message: "Failed to gzip archive.")
      "#{@temp_folder}/#{tar_filename}.gz"
    end
  end

end
