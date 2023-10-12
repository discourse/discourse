# frozen_string_literal: true

require "compression/engine"

class ThemeStore::ZipImporter < ThemeStore::BaseImporter
  attr_reader :url

  def initialize(filename, original_filename)
    @filename = filename
    @original_filename = original_filename
  end

  def import!
    FileUtils.mkdir(temp_folder)

    available_size = SiteSetting.decompressed_theme_max_file_size_mb
    Compression::Engine
      .engine_for(@original_filename)
      .tap do |engine|
        engine.decompress(temp_folder, @filename, available_size)
        strip_root_directory
      end
  rescue RuntimeError
    raise RemoteTheme::ImportError, I18n.t("themes.import_error.unpack_failed")
  rescue Compression::Zip::ExtractFailed
    raise RemoteTheme::ImportError, I18n.t("themes.import_error.file_too_big")
  end

  def version
    ""
  end

  def strip_root_directory
    root_files = Dir.glob("#{temp_folder}/*")
    if root_files.size == 1 && File.directory?(root_files[0])
      FileUtils.mv(Dir.glob("#{temp_folder}/*/*"), temp_folder)
    end
  end
end
