# frozen_string_literal: true

require "csv"

class CustomEmoji::PreviewImport
  include Service::Base

  EXPECTED_ARCHIVE_ERRORS = [
    CSV::MalformedCSVError,
    Compression::SafeZipReader::MissingEntryError,
    Compression::SafeZipReader::TooManyEntriesError,
    Compression::SafeZipReader::EntryTooLargeError,
    Compression::SafeZipReader::SuspiciousEntryError,
  ].freeze

  params do
    attribute :file

    validates :file, presence: true
  end

  # Has to be done this way rather than in a model step
  # otherwise the error doesn't bubble up correctly
  try(*EXPECTED_ARCHIVE_ERRORS) { step :stage_rows }

  policy :manifest_not_empty
  model :token, :store_preview

  private

  def stage_rows(params:, guardian:)
    context[:rows] = CustomEmoji::Action::StageImportRows.call(
      zip_path: params.file.tempfile.path,
      acting_user: guardian.user,
    )
  end

  def manifest_not_empty(rows:)
    rows.present?
  end

  def store_preview(rows:, guardian:)
    CustomEmoji::ImportPreviewCache.new(guardian.user).store(rows)
  end
end
