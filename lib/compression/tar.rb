# frozen_string_literal: true

require 'rubygems/package'

module Compression
  class Tar < Strategy
    def extension
      '.tar'
    end

    def compress(path, target_name)
      tar_filename = sanitize_filename("#{target_name}.tar")
      Discourse::Utils.execute_command('tar', '--create', '--file', tar_filename, target_name, failure_message: "Failed to tar file.")

      sanitize_path("#{path}/#{tar_filename}")
    end

    private

    def extract_folder(_entry, _entry_path); end

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
  end
end
