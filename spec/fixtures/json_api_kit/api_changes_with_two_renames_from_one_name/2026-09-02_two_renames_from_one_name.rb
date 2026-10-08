# frozen_string_literal: true

class TwoRenamesFromOneName < JsonApiKit::VersionChange
  version "2026-09-02"
  description "A change that renames one attribute twice."

  resource :widgets do
    renamed_attribute from: :label, to: :name
    renamed_attribute from: :label, to: :title
  end
end
