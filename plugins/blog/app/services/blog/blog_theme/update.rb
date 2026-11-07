# frozen_string_literal: true

# Saves a new revision of a theme draft. Active readers keep their snapshot
# until the draft is activated again.
class Blog::BlogTheme::Update
  include Service::Base

  params(base_class: Blog::BlogTheme::Create::Contract) do
    attribute :theme_id, :string
    attribute :revision, :integer

    validates :theme_id, :revision, presence: true
  end

  # Provenance of a Git pull, set by Pull rather than by request params.
  options { attribute :source }

  policy :can_manage_themes

  transaction do
    model :theme
    policy :revision_is_current, class_name: Blog::BlogTheme::Policy::RevisionIsCurrent
    model :revised_theme, :revise_theme
    step :log_save
  end

  private

  def can_manage_themes(guardian:)
    guardian.is_admin?
  end

  def fetch_theme(params:)
    Blog::BlogTheme.find_and_lock(params.theme_id)
  end

  def revise_theme(params:, options:, theme:)
    Blog::BlogTheme.revise(theme, params.theme_attributes, source: options.source)
  end

  def log_save(guardian:, revised_theme:)
    Blog::BlogTheme::Action::LogStaffAction.call(
      actor: guardian.user,
      theme: revised_theme,
      event: "save",
    )
  end
end
