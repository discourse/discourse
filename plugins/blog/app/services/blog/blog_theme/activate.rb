# frozen_string_literal: true

# Publishes a frozen snapshot of a theme draft, or a preset, to readers.
class Blog::BlogTheme::Activate
  include Service::Base

  params do
    attribute :theme_id, :string
    attribute :revision, :integer
    attribute :blog_id, :integer

    validates :theme_id, :revision, presence: true
  end

  policy :can_manage_themes
  model :blog

  lock do
    transaction do
      model :theme
      policy :revision_is_current, class_name: Blog::BlogTheme::Policy::RevisionIsCurrent
      model :active_theme, :activate_theme
      step :prune_snapshots
      step :log_activation
    end
  end

  private

  def can_manage_themes(guardian:)
    guardian.is_admin?
  end

  # Choosing a theme for each blog comes with the admin pages for blogs.
  def fetch_blog(params:)
    return Blog::Instance.default_blog if params.blog_id.nil?
    Blog::Instance.find_cached(params.blog_id)
  end

  def fetch_theme(params:)
    Blog::ThemePresets.find(params.theme_id) || Blog::BlogTheme.find_and_lock(params.theme_id)
  end

  def activate_theme(theme:, blog:)
    Blog::BlogTheme.activate(theme, blog)
  end

  def prune_snapshots
    Blog::BlogTheme.prune_snapshots
  end

  def log_activation(guardian:, active_theme:)
    Blog::BlogTheme::Action::LogStaffAction.call(
      actor: guardian.user,
      theme: active_theme,
      event: "activate",
    )
  end
end
