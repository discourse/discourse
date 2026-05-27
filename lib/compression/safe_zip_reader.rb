# frozen_string_literal: true

require "zip"

module Compression
  class SafeZipReader
    Error = Class.new(StandardError)
    EntryTooLargeError = Class.new(Error)
    MissingEntryError = Class.new(Error)
    TooManyEntriesError = Class.new(Error)
    SuspiciousEntryError = Class.new(Error)

    DEFAULT_READ_CHUNK_BYTES = 16 * 1024

    attr_reader :zip_file, :remaining_total_bytes

    def self.open(path, **kwargs)
      ::Zip::File.open(path) do |zip_file|
        reader = new(zip_file, **kwargs)
        reader.validate!

        yield(reader)
      end
    end

    def initialize(
      zip_file,
      max_entries: nil,
      max_total_bytes: nil,
      max_compression_ratio: nil,
      read_chunk_bytes: DEFAULT_READ_CHUNK_BYTES
    )
      @zip_file = zip_file
      @max_entries = max_entries
      @remaining_total_bytes = max_total_bytes
      @max_compression_ratio = max_compression_ratio
      @read_chunk_bytes = read_chunk_bytes
    end

    def validate!
      if @max_entries && entries.size > @max_entries
        raise TooManyEntriesError, "Zip archive has too many entries"
      end

      self
    end

    def entries
      zip_file.entries
    end

    def find_entry(name)
      zip_file.find_entry(name)
    end

    def read_entry(entry_or_name, max_bytes:, required: false)
      entry = resolve_entry(entry_or_name)
      if required && (entry.nil? || entry.directory?)
        raise MissingEntryError, "Zip entry #{entry_name(entry_or_name)} is missing"
      end
      return if entry.nil? || entry.directory?

      data = +""
      stream_entry(entry, max_bytes: max_bytes) { |chunk| data << chunk }
      data
    end

    def stream_entry_to_file(entry_or_name, file, max_bytes:, required: false)
      entry = resolve_entry(entry_or_name)
      if required && (entry.nil? || entry.directory?)
        raise MissingEntryError, "Zip entry #{entry_name(entry_or_name)} is missing"
      end
      return if entry.nil? || entry.directory?

      stream_entry(entry, max_bytes: max_bytes) { |chunk| file.write(chunk) }
    end

    private

    def resolve_entry(entry_or_name)
      entry_or_name.respond_to?(:get_input_stream) ? entry_or_name : find_entry(entry_or_name)
    end

    def entry_name(entry_or_name)
      entry_or_name.respond_to?(:name) ? entry_or_name.name : entry_or_name
    end

    def stream_entry(entry, max_bytes:)
      limit = entry_limit(max_bytes)
      validate_entry_metadata!(entry, limit)

      bytes_read = 0
      entry.get_input_stream do |stream|
        while (chunk = stream.read(@read_chunk_bytes))
          bytes_read += chunk.bytesize
          raise EntryTooLargeError, "Zip entry #{entry.name} is too large" if bytes_read > limit

          yield chunk
        end
      end

      @remaining_total_bytes -= bytes_read if @remaining_total_bytes
      bytes_read
    end

    def entry_limit(max_bytes)
      limit = [max_bytes, @remaining_total_bytes].compact.min
      raise EntryTooLargeError, "Zip content is too large" if limit.nil? || limit <= 0

      limit
    end

    def validate_entry_metadata!(entry, limit)
      if entry.size && entry.size > limit
        raise EntryTooLargeError, "Zip entry #{entry.name} is too large"
      end

      return if @max_compression_ratio.nil?
      return if entry.compressed_size.nil? || entry.compressed_size <= 0
      return if entry.size.nil?

      if (entry.size.to_f / entry.compressed_size) > @max_compression_ratio
        raise SuspiciousEntryError, "Zip entry #{entry.name} has a suspicious compression ratio"
      end
    end
  end
end
