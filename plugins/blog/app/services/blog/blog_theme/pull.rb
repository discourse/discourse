# frozen_string_literal: true

# Refreshes a Git-imported draft from its repository as a new revision.
class Blog::BlogTheme::Pull
  include Service::Base

  params do
    attribute :theme_id, :string
    attribute :revision, :integer

    validates :theme_id, :revision, presence: true
  end

  policy :can_manage_themes
  model :theme
  policy :imported_from_repository
  try(*Blog::ThemeImporter::ERRORS) { step :pull_from_repository }

  private

  def can_manage_themes(guardian:)
    guardian.is_admin?
  end

  def fetch_theme(params:)
    Blog::BlogTheme.find_by(id: params.theme_id)
  end

  def imported_from_repository(theme:)
    theme["source"].present?
  end

  # The importer raises for unusable sources, so this can't be a model step.
  def pull_from_repository(params:, guardian:, theme:)
    context[:pulled_theme] = Blog::ThemeImporter.import(
      repository: theme["source"]["repository"],
      branch: theme["source"]["branch"],
      user: guardian.user,
      id: theme["id"],
      revision: params.revision,
    )
  end
end
