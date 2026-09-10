# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    Rename =
      Data.define(:kind, :type, :from, :to) do
        def current(name)
          return name unless applies_to?(name) && name.value == from
          name.with(value: to)
        end

        def previous(name)
          return name unless introduces?(name)
          name.with(value: from)
        end

        def introduces?(name) = applies_to?(name) && name.value == to

        private

        def applies_to?(name) = name.kind == kind && name.type == type
      end
  end
end
