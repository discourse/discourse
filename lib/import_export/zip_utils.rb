# frozen_string_literal: true

require 'zip'

module ImportExport
  class ZipUtils
    def zip_directory(path, export_name)
      zip_filename = "#{export_name}.zip"
      absolute_path = "#{path}/#{export_name}"
      entries = Dir.entries(absolute_path) - %w[. ..]

      Zip::File.open(zip_filename, Zip::File::CREATE) do |zipfile|
        write_entries(entries, absolute_path, '', zipfile)
      end

      "#{absolute_path}.zip"
    end

    def unzip_directory(path, zip_filename, allow_non_root_folder: false)
      Zip::File.open(zip_filename) do |zip_file|
        root = root_folder_present?(zip_file, allow_non_root_folder) ? '' : 'unzipped/'
        zip_file.each do |entry|
          entry_path = File.join(path, "#{root}#{entry.name}")
          FileUtils.mkdir_p(File.dirname(entry_path))
          entry.extract(entry_path)
        end
      end
    end

    private

    def root_folder_present?(filenames, allow_non_root_folder)
      filenames.map { |p| p.name.split('/').first }.uniq.size == 1 || allow_non_root_folder
    end

    # A helper method to make the recursion work.
    def write_entries(entries, base_path, path, zipfile)
      entries.each do |e|
        zipfile_path = path == '' ? e : File.join(path, e)
        disk_file_path = File.join(base_path, zipfile_path)

        if File.directory? disk_file_path
          recursively_deflate_directory(disk_file_path, zipfile, base_path, zipfile_path)
        else
          put_into_archive(disk_file_path, zipfile, zipfile_path)
        end
      end
    end

    def recursively_deflate_directory(disk_file_path, zipfile, base_path, zipfile_path)
      zipfile.mkdir zipfile_path
      subdir = Dir.entries(disk_file_path) - %w[. ..]
      write_entries subdir, base_path, zipfile_path, zipfile
    end

    def put_into_archive(disk_file_path, zipfile, zipfile_path)
      zipfile.add(zipfile_path, disk_file_path)
    end
  end
end
