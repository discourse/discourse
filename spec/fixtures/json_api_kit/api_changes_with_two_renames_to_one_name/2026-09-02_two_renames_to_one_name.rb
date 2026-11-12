# frozen_string_literal: true

class TwoRenamesToOneName < JsonApiKit::VersionChange
  version "2026-09-02"
  description "A change that renames two attributes to one name."

  resource :widgets do
    renamed_attribute from: :label, to: :title
    renamed_attribute from: :caption, to: :title
  end
end
