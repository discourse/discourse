# frozen_string_literal: true

require "csv"

class CustomEmoji::Action::BuildExportArchive < Service::ActionBase
  MANIFEST_FILENAME = "emojis.csv"
  MANIFEST_HEADERS = %w[name group filename].freeze

  option :emojis

  def call
    temp_dir = Dir.mktmpdir("discourse_emoji_export_")
    zip_path = nil

    begin
      write_images(temp_dir)
      write_manifest(temp_dir)
      zip_path = Compression::Zip.new.compress(File.dirname(temp_dir), File.basename(temp_dir))
      File.binread(zip_path)
    ensure
      FileUtils.rm_rf(temp_dir)
      File.delete(zip_path) if zip_path && File.exist?(zip_path)
    end
  end

  private

  def write_images(temp_dir)
    emojis.each do |emoji|
      File.binwrite(File.join(temp_dir, image_filename(emoji)), emoji.upload.content)
    end
  end

  def write_manifest(temp_dir)
    CSV.open(File.join(temp_dir, MANIFEST_FILENAME), "w") do |csv|
      csv << MANIFEST_HEADERS
      emojis.each do |emoji|
        csv << [emoji.name, CustomEmoji.normalize_group(emoji.group), image_filename(emoji)]
      end
    end
  end

  def image_filename(emoji)
    "#{emoji.name}.#{emoji.upload.extension}"
  end
end
