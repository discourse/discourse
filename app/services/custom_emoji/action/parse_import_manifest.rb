# frozen_string_literal: true

require "csv"

class CustomEmoji::Action::ParseImportManifest < Service::ActionBase
  MANIFEST_FILENAME = "emojis.csv"
  MAX_MANIFEST_BYTES = 1.megabyte
  SUPPORTED_EXTENSIONS = %w[png gif svg].freeze

  option :reader

  def call
    filenames_seen = Set.new
    names_seen = Set.new

    parse_manifest.map.with_index do |csv_row, index|
      row =
        CustomEmoji::ImportRow.new(
          index:,
          name: Emoji.sanitize_emoji_name(csv_row["name"].to_s.strip),
          group: CustomEmoji.normalize_group(csv_row["group"]),
          filename: csv_row["filename"].to_s.strip,
        )
      validate_row(row, filenames_seen:, names_seen:)
      filenames_seen << row.filename
      names_seen << row.name
      row
    end
  end

  private

  def parse_manifest
    CSV.parse(
      reader.read_entry(MANIFEST_FILENAME, max_bytes: MAX_MANIFEST_BYTES, required: true),
      headers: true,
    )
  end

  def validate_row(row, filenames_seen:, names_seen:)
    errors = name_errors(row, names_seen) + filename_errors(row, filenames_seen)
    if row.group.present? && row.group.length > CustomEmoji::MAX_GROUP_LENGTH
      errors << translated_error("group_too_long")
    end
    row.mark_invalid(*errors) if errors.any?
  end

  def name_errors(row, names_seen)
    return [translated_error("missing_name")] if row.name.blank?
    return [translated_error("duplicate_name")] if names_seen.include?(row.name)
    []
  end

  def filename_errors(row, filenames_seen)
    return [translated_error("missing_filename")] if row.filename.blank?

    errors = []
    extension = File.extname(row.filename).delete(".").downcase
    if SUPPORTED_EXTENSIONS.exclude?(extension)
      errors << translated_error("unsupported_extension", ext: extension)
    end
    errors << translated_error("duplicate_filename") if filenames_seen.include?(row.filename)
    errors
  end

  def translated_error(key, **args)
    I18n.t("emoji.import.validation.#{key}", **args)
  end
end
