# frozen_string_literal: true

require_dependency 'compression/strategy'

module Compression
  class Tar < Strategy
    def self.can_handle?(file_name)
      file_name.include?('.tar')
    end

    def compress(path, target_name)
      tar_filename = "#{target_name}.tar"
      Discourse::Utils.execute_command('tar', '--create', '--file', tar_filename, target_name, failure_message: "Failed to tar file.")

      "#{path}/#{tar_filename}"
    end

    private

    def extract_folder(_entry, _entry_path); end

    def calculate_available_size(compressed_file_path, compressed_file)
      @available_size ||= [(File.size(compressed_file_path) * 5), 10000000].max
    end

    def get_compressed_file_stream(compressed_file_path)
      file_stream = IO.new(IO.sysopen(compressed_file_path))
      tar_extract = Gem::Package::TarReader.new(file_stream)
      tar_extract.rewind
      yield(tar_extract)
    end

    def build_entry_path(_compressed_file, dest_path, compressed_file_path, entry, _allow_non_root_folder)
      File.join(dest_path, entry.full_name).tap do |entry_path|
        FileUtils.mkdir_p(File.dirname(entry_path))
      end
    end

    def extract_file(entry, entry_path, available_size)
      remaining_size = available_size

      if ::File.exist?(entry_path)
        raise ::Zip::DestinationFileExistsError,
              "Destination '#{entry_path}' already exists"
      end # Change this later.

      ::File.open(entry_path, 'wb') do |os|
        buf = ''.dup
        while (buf = entry.read(chunk_size))
          remaining_size -= chunk_size
          raise ExtractFailed if remaining_size.negative?
          os << buf
        end
      end

      remaining_size
    end
  end
end
