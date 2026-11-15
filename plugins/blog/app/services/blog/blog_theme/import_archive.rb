# frozen_string_literal: true

# Saves an uploaded theme ZIP as a new, inactive draft.
class Blog::BlogTheme::ImportArchive
  include Service::Base

  MAX_ARCHIVE_BYTES = 2.megabytes

  params do
    attribute :file

    validates :file, presence: true
    validate :file_is_zip_archive

    private

    def file_is_zip_archive
      return if file.blank? || zip_archive?
      errors.add(:file, :invalid)
    end

    def zip_archive?
      return false if !file.is_a?(ActionDispatch::Http::UploadedFile)
      return false if file.size > MAX_ARCHIVE_BYTES
      File.extname(file.original_filename).casecmp?(".zip")
    end
  end

  policy :can_manage_themes
  try(Blog::ThemeImporter::InvalidTheme) { step :read_archive }
  step :create_theme

  private

  def can_manage_themes(guardian:)
    guardian.is_admin?
  end

  # The importer raises for invalid archives, so this can't be a model step.
  def read_archive(params:)
    context[:imported_theme] = Blog::ThemeImporter.read_archive(params.file.path)
  end

  def create_theme(imported_theme:, guardian:)
    Blog::BlogTheme::Create.call(params: imported_theme.attributes, guardian:) do
      on_success { |theme:| context[:theme] = theme }
      on_failed_contract { |contract| fail!(contract.errors.full_messages.first) }
      on_failed_policy(:within_theme_limit) { |policy| fail!(policy.reason) }
    end
  end
end
