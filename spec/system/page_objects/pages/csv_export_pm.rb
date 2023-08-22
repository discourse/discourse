# frozen_string_literal: true

module PageObjects
  module Pages
    class CSVExportPM < PageObjects::Pages::Base
      def initialize
        super
        @downloaded_files = []
      end

      def download_and_extract
        click_link ".zip"
        Downloads.wait_for_download

        zip_name = find("a.attachment").text
        zip_path = File.join(Downloads::FOLDER, zip_name)
        @downloaded_files << zip_path

        csv_path = unzip(zip_path).first
        @downloaded_files << csv_path
        CSV.read(csv_path)
      end

      def clear_downloads
        @downloaded_files.each { |file| FileUtils.rm(file) }
        @downloaded_files = []
      end

      def has_download_link?
        find(:link, ".zip").present?
      end

      private

      def unzip(file)
        paths = []
        Zip::File.open(file) do |zip_file|
          zip_file.each do |f|
            path = File.join(Downloads::FOLDER, f.name)
            zip_file.extract(f, path)
            paths << path
          end
        end

        paths
      end
    end
  end
end
