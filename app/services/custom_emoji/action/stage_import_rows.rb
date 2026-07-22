# frozen_string_literal: true

class CustomEmoji::Action::StageImportRows < Service::ActionBase
  MAX_ENTRIES = 1000
  MAX_TOTAL_BYTES = 500.megabytes
  MAX_COMPRESSION_RATIO = 20

  option :zip_path
  option :acting_user

  def call
    Compression::SafeZipReader.open(
      zip_path,
      max_entries: MAX_ENTRIES,
      max_total_bytes: MAX_TOTAL_BYTES,
      max_compression_ratio: MAX_COMPRESSION_RATIO,
    ) do |reader|
      rows = CustomEmoji::Action::ParseImportManifest.call(reader:)
      existing_emojis = existing_emojis_for(rows)

      rows.map do |row|
        next row if row.invalid?

        CustomEmoji::Action::StageImportRow.call(
          reader:,
          row:,
          acting_user:,
          existing_emoji: existing_emojis[row.name],
        )
      end
    end
  end

  private

  def existing_emojis_for(rows)
    names = rows.reject(&:invalid?).map(&:name)
    CustomEmoji.where(name: names).includes(:upload).index_by(&:name)
  end
end
