# frozen_string_literal: true

module PageObjects
  module Pages
    class CSVExportPM < PageObjects::Pages::Base
      def download_and_extract
        click_link ".zip"
        sleep 3 # fixme try to get rid of sleep
        zip_name = find("a.attachment").text
        zip_path = File.join(Downloads::FOLDER, zip_name)
        csv_path = unzip(zip_path).first
        CSV.read(csv_path)
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
