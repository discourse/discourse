# frozen_string_literal: true

module JsonApiKit
  # The input scopes that version changes retained for a listing, newest first; the last one is
  # the one a request pinned before every change uses.
  class InputScopeHistory < RemovedDeclarations
    private

    def each_from(change, type, collection, &)
      change.each_input_scope_change(type, collection, &)
    end
  end
end
