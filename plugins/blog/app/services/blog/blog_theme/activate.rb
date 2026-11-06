# frozen_string_literal: true

# Publishes a frozen snapshot of a theme draft to readers.
class Blog::BlogTheme::Activate
  include Service::Base

  params do
    attribute :theme_id, :string
    attribute :revision, :integer

    validates :theme_id, :revision, presence: true
  end

  policy :can_manage_themes

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

  def fetch_theme(params:)
    Blog::BlogTheme.find_and_lock(params.theme_id)
  end

  def activate_theme(theme:)
    Blog::BlogTheme.activate(theme)
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
