# frozen_string_literal: true

module ThemeStore
  class DirectoryImporter < BaseImporter
    def initialize(theme_dir)
      @theme_dir = theme_dir
    end

    def import!
      FileUtils.mkdir_p(temp_folder)
      FileUtils.cp_r("#{@theme_dir}/.", temp_folder)
    end
  end
end
