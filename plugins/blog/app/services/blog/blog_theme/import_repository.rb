# frozen_string_literal: true

# Clones a public Git repository and saves its theme as a new, inactive draft.
class Blog::BlogTheme::ImportRepository
  include Service::Base

  MAX_REPOSITORY_LENGTH = 1000
  MAX_BRANCH_LENGTH = 200

  params do
    attribute :repository, :string
    attribute :branch, :string

    before_validation { self.branch = branch.presence }

    validates :repository, presence: true
    validate :repository_is_public_https_url
    # A leading dash would be read by Git as an option.
    validates :branch,
              length: {
                maximum: MAX_BRANCH_LENGTH,
              },
              format: {
                without: /\A-|[\x00-\x20]/,
              },
              allow_nil: true

    private

    def repository_is_public_https_url
      return if repository.blank? || public_https_url?
      errors.add(:base, I18n.t("blog.themes.repository_invalid"))
    end

    def public_https_url?
      return false if repository.length > MAX_REPOSITORY_LENGTH
      uri = URI.parse(repository)
      return false if !uri.is_a?(URI::HTTPS) || uri.host.blank?
      !uri.userinfo && !uri.query && !uri.fragment
    rescue URI::InvalidURIError
      false
    end
  end

  policy :can_manage_themes
  policy :can_import_repository
  try(Blog::ThemeImporter::InvalidTheme, RemoteTheme::ImportError) { step :read_repository }
  step :create_theme

  private

  def can_manage_themes(guardian:)
    guardian.is_admin?
  end

  def can_import_repository(guardian:, params:)
    guardian.allowed_theme_repo_import?(params.repository)
  end

  # The importer raises for unusable sources, so this can't be a model step.
  def read_repository(params:)
    context[:imported_theme] = Blog::ThemeImporter.read_repository(
      params.repository,
      branch: params.branch,
    )
  end

  def create_theme(imported_theme:, guardian:)
    Blog::BlogTheme::Create.call(
      params: imported_theme.attributes,
      options: {
        source: imported_theme.source,
      },
      guardian:,
    ) do
      on_success { |theme:| context[:theme] = theme }
      on_failed_contract { |contract| fail!(contract.errors.full_messages.first) }
      on_failed_policy(:within_theme_limit) { |policy| fail!(policy.reason) }
    end
  end
end
