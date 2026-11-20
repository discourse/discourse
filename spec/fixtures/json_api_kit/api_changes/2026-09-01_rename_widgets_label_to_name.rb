# frozen_string_literal: true

class RenameWidgetsLabelToName < JsonApiKit::VersionChange
  version "2026-09-01"
  description "The `label` attribute of the widgets resource is renamed to `name`."

  resource :widgets do
    renamed_attribute from: :label, to: :name
  end
end
