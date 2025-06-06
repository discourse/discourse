# frozen_string_literal: true

class BackupFile
  include ActiveModel::SerializerSupport

  attr_reader :filename, :size, :last_modified, :source

  def initialize(filename:, size:, last_modified:, source: nil)
    @filename = filename
    @size = size
    @last_modified = last_modified
    @source = source
  end

  def ==(other)
    attributes == other.attributes
  end

  def self.download(url)
    FileHelper.download(
      url,
      max_file_size: Float::INFINITY,
      tmp_file_name: File.basename(URI.parse(url).path),
      follow_redirect: true,
      skip_rate_limit: true,
      validate_uri: false,
      verbose: true,
    )
  end

  protected

  def attributes
    [@filename, @size, @last_modified, @source]
  end
end
