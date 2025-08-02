# frozen_string_literal: true

module ThemeStore
  class DirectoryImporter < BaseImporter
    def initialize(theme_dir)
      @theme_dir = theme_dir
    end

    def import!
      FileUtils.mkdir_p(temp_folder)
      Dir.glob("*", base: @theme_dir) do |entry|
        next if %w[node_modules src spec].include?(entry)
        FileUtils.cp_r(File.join(@theme_dir, entry), temp_folder)
      end
    end
  end
end
