# frozen_string_literal: true

# Editors act on the revision they loaded; anything else would silently discard
# another admin's change.
class Blog::BlogTheme::Policy::RevisionIsCurrent < Service::PolicyBase
  def call
    context.theme["revision"] == context.params.revision
  end

  def reason
    I18n.t("blog.themes.stale")
  end
end
