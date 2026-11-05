# frozen_string_literal: true

# Clones a public Git repository and saves its theme as a new, inactive draft.
class Blog::BlogTheme::ImportRepository
  include Service::Base

  params do
    attribute :repository, :string
    attribute :branch, :string

    validates :repository, presence: true
  end

  policy :can_manage_themes
  try(*Blog::ThemeImporter::ERRORS) { step :import_repository }

  private

  def can_manage_themes(guardian:)
    guardian.is_admin?
  end

  # The importer raises for unusable sources, so this can't be a model step.
  def import_repository(params:, guardian:)
    context[:theme] = Blog::ThemeImporter.import(
      repository: params.repository,
      branch: params.branch,
      user: guardian.user,
    )
  end
end
