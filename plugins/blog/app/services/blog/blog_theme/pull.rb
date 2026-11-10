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
  policy :can_import_repository
  policy :revision_is_current, class_name: Blog::BlogTheme::Policy::RevisionIsCurrent
  try(Blog::ThemeImporter::InvalidTheme, RemoteTheme::ImportError) { step :read_repository }
  step :revise_theme

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

  def can_import_repository(guardian:, theme:)
    guardian.allowed_theme_repo_import?(theme["source"]["repository"])
  end

  # The importer raises for unusable sources, so this can't be a model step.
  def read_repository(theme:)
    context[:imported_theme] = Blog::ThemeImporter.read_repository(
      theme["source"]["repository"],
      branch: theme["source"]["branch"],
    )
  end

  # The draft can change or disappear while the repository is cloned.
  def revise_theme(params:, guardian:, imported_theme:)
    Blog::BlogTheme::Update.call(
      params:
        imported_theme.attributes.merge(
          "theme_id" => params.theme_id,
          "revision" => params.revision,
        ),
      options: {
        source: imported_theme.source,
      },
      guardian:,
    ) do
      on_success { |revised_theme:| context[:pulled_theme] = revised_theme }
      on_failed_contract { |contract| fail!(contract.errors.full_messages.first) }
      on_model_not_found(:theme) { fail!(I18n.t("blog.themes.stale")) }
      on_failed_policy(:revision_is_current) { |policy| fail!(policy.reason) }
    end
  end
end
