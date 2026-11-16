# frozen_string_literal: true

# Deletes an unused theme draft. The active theme must be replaced first so
# readers never lose their design.
class Blog::BlogTheme::Destroy
  include Service::Base

  params do
    attribute :theme_id, :string
    attribute :revision, :integer

    validates :theme_id, :revision, presence: true
  end

  policy :can_manage_themes

  transaction do
    model :theme
    policy :revision_is_current, class_name: Blog::BlogTheme::Policy::RevisionIsCurrent
    policy :theme_is_inactive
    step :destroy_theme
    step :log_deletion
  end

  private

  def can_manage_themes(guardian:)
    guardian.is_admin?
  end

  def fetch_theme(params:)
    Blog::BlogTheme.find_and_lock(params.theme_id)
  end

  def theme_is_inactive(theme:)
    !Blog::BlogTheme.active?(theme)
  end

  def destroy_theme(theme:)
    Blog::BlogTheme.destroy(theme)
  end

  def log_deletion(guardian:, theme:)
    Blog::BlogTheme::Action::LogStaffAction.call(actor: guardian.user, theme:, event: "delete")
  end
end
