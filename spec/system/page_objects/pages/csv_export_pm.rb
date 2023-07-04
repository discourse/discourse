# frozen_string_literal: true

module PageObjects
  module Pages
    class CSVExportPM < PageObjects::Pages::Base
      def download_and_extract(export_name)
        click_link "#{export_name}-"
        sleep 3 # fixme try to get rid of sleep
        file_name = find("a.attachment").text
        csv_file_path = unzip("#{Downloads::FOLDER}/#{file_name}")
        CSV.read(csv_file_path)
      end

      private

      def unzip(file)
        destination = Downloads::FOLDER
        FileUtils.mkdir_p(destination)

        path = ""
        Zip::File.open(file) do |zip_files|
          csv_file = zip_files.first
          path = File.join(destination, csv_file.name)
          zip_files.extract(csv_file, path) unless File.exist?(path)
        end

        path
      end
    end
  end
end
