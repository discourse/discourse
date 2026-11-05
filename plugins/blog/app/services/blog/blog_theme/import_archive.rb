# frozen_string_literal: true

# Saves an uploaded theme ZIP as a new, inactive draft.
class Blog::BlogTheme::ImportArchive
  include Service::Base

  params do
    attribute :file

    validates :file, presence: true
  end

  policy :can_manage_themes
  try(*Blog::ThemeImporter::ERRORS) { step :import_archive }

  private

  def can_manage_themes(guardian:)
    guardian.is_admin?
  end

  # The importer raises for invalid archives, so this can't be a model step.
  def import_archive(params:, guardian:)
    context[:theme] = Blog::ThemeImporter.import_file(file: params.file, user: guardian.user)
  end
end
