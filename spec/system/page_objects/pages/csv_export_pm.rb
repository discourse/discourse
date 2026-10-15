# frozen_string_literal: true

module PageObjects
  module Pages
    class CSVExportPM < PageObjects::Pages::Base
      def initialize
        super
        @downloaded_files = []
      end

      def download_and_extract
        zip_path =
          browser_page.then do |pw_page|
            pw_page
              .expect_download do
                browser_root
                  .locator("[id=#{".zip".to_s.to_json}], [name=#{".zip".to_s.to_json}]")
                  .or(browser_root.get_by_role("link", name: ".zip"))
                  .filter(visible: true)
                  .click
              end
              .path
          end

        csv_path = unzip(zip_path).first
        @downloaded_files << csv_path
        CSV.read(csv_path)
      end

      def clear_downloads
        @downloaded_files.each { |file| FileUtils.rm_f(file) }
        @downloaded_files = []
      end

      def has_download_link?
        PlaywrightMatchers.be_visible.matches?(browser_root.get_by_role("link", name: ".zip"))
      end

      private

      def unzip(file)
        paths = []
        Zip::File.open(file) do |zip_file|
          zip_file.each do |f|
            f.extract(f.name, destination_directory: Downloads::FOLDER)
            paths << File.join(Downloads::FOLDER, f.name)
          end
        end

        paths
      end
    end
  end
end
