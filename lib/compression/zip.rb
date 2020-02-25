# frozen_string_literal: true

require 'zip'

module Compression
  class Zip < Strategy
    def extension
      '.zip'
    end

    def compress(path, target_name)
      absolute_path = sanitize_path("#{path}/#{target_name}")
      zip_filename = "#{absolute_path}.zip"

      ::Zip::File.open(zip_filename, ::Zip::File::CREATE) do |zipfile|
        if File.directory?(absolute_path)
          entries = Dir.entries(absolute_path) - %w[. ..]
          write_entries(entries, absolute_path, '', zipfile)
        else
          put_into_archive(absolute_path, zipfile, target_name)
        end
      end

      zip_filename
    end

    private

    def extract_folder(entry, entry_path)
      entry.extract(entry_path)
    end

    def get_compressed_file_stream(compressed_file_path)
      zip_file = ::Zip::File.open(compressed_file_path)
      yield(zip_file)
    end

    def build_entry_path(compressed_file, dest_path, compressed_file_path, entry, allow_non_root_folder)
      folder_name = compressed_file_path.split('/').last.gsub('.zip', '')
      root = root_folder_present?(compressed_file, allow_non_root_folder) ? '' : "#{folder_name}/"

      File.join(dest_path, "#{root}#{entry.name}").tap do |entry_path|
        FileUtils.mkdir_p(File.dirname(entry_path))
      end
    end

    def root_folder_present?(filenames, allow_non_root_folder)
      filenames.map { |p| p.name.split('/').first }.uniq.size == 1 || allow_non_root_folder
    end

    def extract_file(entry, entry_path, available_size)
      remaining_size = available_size

      if ::File.exist?(entry_path)
        raise ::Zip::DestinationFileExistsError,
              "Destination '#{entry_path}' already exists"
      end

      ::File.open(entry_path, 'wb') do |os|
        entry.get_input_stream do |is|
          entry.set_extra_attributes_on_path(entry_path)

          buf = ''.dup
          while (buf = is.sysread(chunk_size, buf))
            remaining_size -= chunk_size
            raise ExtractFailed if remaining_size.negative?
            os << buf
          end
        end
      end

      remaining_size
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
