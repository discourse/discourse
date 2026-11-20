# frozen_string_literal: true

# Saves a theme from the list of popular themes (see PopularThemes) as an
# appearance change without making it the default, so it can be previewed,
# then made live with AppearanceChange::Activate and switched back with
# AppearanceChange::Revert.
#
# A theme the site doesn't have yet is installed first. One it already has is
# used as it is, never installed a second time, and stays when the change is
# removed. A change already saved for it and not yet made live is reused.
class AppearanceChange::InstallTheme
  include Service::Base

  params do
    attribute :remote_url, :string

    validates :remote_url, presence: true
  end

  model :popular_theme
  model :installed_theme, optional: true

  only_if(:needs_install) do
    policy :can_create_theme
    policy :allowed_theme_repo
    step :import_theme
  end

  only_if(:already_installed) do
    policy :can_edit_theme
    policy :not_default
  end

  model :appearance_change, :find_or_create_appearance_change

  private

  def fetch_popular_theme(params:)
    PopularThemes.themes.find { |entry| entry[:remote_url] == params.remote_url }
  end

  def fetch_installed_theme(popular_theme:)
    url = popular_theme[:remote_url].downcase
    Theme
      .where(component: false)
      .joins(:remote_theme)
      .where("lower(remote_themes.remote_url) IN (?)", [url, "#{url}.git"])
      .order(:id)
      .first
  end

  def needs_install(installed_theme:)
    installed_theme.nil?
  end

  def already_installed(installed_theme:)
    installed_theme.present?
  end

  def can_create_theme(guardian:)
    guardian.can_create_theme?
  end

  def allowed_theme_repo(guardian:, popular_theme:)
    guardian.allowed_theme_repo_import?(popular_theme[:remote_url])
  end

  def can_edit_theme(guardian:, installed_theme:)
    guardian.can_edit_theme?(installed_theme)
  end

  def not_default(installed_theme:)
    !installed_theme.default?
  end

  def import_theme(guardian:, popular_theme:)
    theme = RemoteTheme.import_theme(popular_theme[:remote_url], guardian.user, guardian:)
    StaffActionLogger.new(guardian.user).log_theme_change(nil, theme)
    context[:installed_theme] = theme
    context[:imported] = true
  rescue RemoteTheme::ImportError => e
    fail!(e.message)
  end

  def find_or_create_appearance_change(guardian:, installed_theme:)
    existing =
      AppearanceChange
        .where(kind: %i[installed_theme existing_theme], theme: installed_theme)
        .drafts
        .order(:id)
        .last
    return existing if existing

    AppearanceChange.create(
      kind: context[:imported] ? :installed_theme : :existing_theme,
      name: installed_theme.name,
      theme: installed_theme,
      light_color_scheme_id: installed_theme.color_scheme_id,
      dark_color_scheme_id: installed_theme.dark_color_scheme_id,
      site_settings: {
      },
      user: guardian.user,
    )
  end
end
