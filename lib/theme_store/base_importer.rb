# frozen_string_literal: true

module ThemeStore
  class BaseImporter
    def import!
      raise "Not implemented"
    end

    def [](value)
      fullpath = real_path(value)
      return nil unless fullpath
      File.read(fullpath)
    end

    def real_path(relative)
      fullpath = "#{temp_folder}/#{relative}"
      return nil unless File.exist?(fullpath)

      # careful to handle symlinks here, don't want to expose random data
      fullpath = Pathname.new(fullpath).realpath.to_s

      if fullpath && fullpath.start_with?(temp_folder)
        fullpath
      else
        nil
      end
    end

    def file_size(path)
      fullpath = real_path(path)
      return -1 unless fullpath
      File.size(fullpath)
    end

    def all_files
      Dir.glob("**/**", base: temp_folder).reject { |f| File.directory?(File.join(temp_folder, f)) }
    end

    def cleanup!
      FileUtils.rm_rf(temp_folder)
    end

    def temp_folder
      @temp_folder ||= "#{Pathname.new(Dir.tmpdir).realpath}/discourse_theme_#{SecureRandom.hex}"
    end
  end
end
