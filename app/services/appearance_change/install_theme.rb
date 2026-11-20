# frozen_string_literal: true

# Installs a theme from the list of popular themes (see PopularThemes) without
# making it the default, and saves it as an appearance change, so it can be
# previewed, then made live with AppearanceChange::Activate and switched back
# with AppearanceChange::Revert.
class AppearanceChange::InstallTheme
  include Service::Base

  params do
    attribute :remote_url, :string

    validates :remote_url, presence: true
  end

  policy :can_create_theme
  model :popular_theme
  policy :allowed_theme_repo
  policy :not_installed
  step :import_theme

  transaction do
    model :appearance_change, :create_appearance_change
    step :log_theme_creation
  end

  private

  def can_create_theme(guardian:)
    guardian.can_create_theme?
  end

  def fetch_popular_theme(params:)
    PopularThemes.themes.find { |entry| entry[:remote_url] == params.remote_url }
  end

  def allowed_theme_repo(guardian:, popular_theme:)
    guardian.allowed_theme_repo_import?(popular_theme[:remote_url])
  end

  # Installing a theme the site already has would make a second copy.
  def not_installed(popular_theme:)
    url = popular_theme[:remote_url]
    !RemoteTheme.where("lower(remote_url) IN (?)", [url.downcase, "#{url.downcase}.git"]).exists?
  end

  def import_theme(guardian:, popular_theme:)
    context[:theme] = RemoteTheme.import_theme(popular_theme[:remote_url], guardian.user, guardian:)
  rescue RemoteTheme::ImportError => e
    fail!(e.message)
  end

  def create_appearance_change(guardian:, theme:)
    AppearanceChange.create(
      kind: :installed_theme,
      name: theme.name,
      theme:,
      light_color_scheme_id: theme.color_scheme_id,
      dark_color_scheme_id: theme.dark_color_scheme_id,
      site_settings: {
      },
      user: guardian.user,
    )
  end

  def log_theme_creation(guardian:, theme:)
    StaffActionLogger.new(guardian.user).log_theme_change(nil, theme)
  end
end
