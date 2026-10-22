# frozen_string_literal: true

module JsonApiKit
  class RemovedFilters < RemovedDeclarations
    private

    def each_from(change, type, collection, &)
      change.each_removed_filter(type, collection, &)
    end
  end
end
