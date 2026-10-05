# frozen_string_literal: true

module JsonApiKit
  class RemovedSorts < RemovedDeclarations
    private

    def each_from(change, type, &)
      change.each_removed_sort(type, &)
    end
  end
end
