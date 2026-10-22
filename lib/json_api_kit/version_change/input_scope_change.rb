# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    # Before the change's version, the listing narrowed with this input scope.
    InputScopeChange = Data.define(:type, :collection, :input_scope)
  end
end
