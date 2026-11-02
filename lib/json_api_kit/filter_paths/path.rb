# frozen_string_literal: true

module JsonApiKit
  class FilterPaths
    Path =
      Data.define(:relationships, :filter, :resource) do
        def self.for(name, resource:)
          return name if name.is_a?(self)
          new(
            relationships: [],
            filter: Name::Filter.new(value: name.to_s, type: resource.type),
            resource:,
          )
        end

        def local? = relationships.empty?

        def declared? = resource.filter_names.include?(filter.value)

        def prepend(relationship) = with(relationships: [relationship, *relationships])

        def member_name(glossary)
          Name::FilterPath.new(relationships:, filter:).member_name(glossary)
        end

        def parameters(value)
          relationships
            .reverse_each
            .reduce({ filter: { filter.value => value } }) do |params, name|
              { forwarded_filters: { name.value => params } }
            end
        end
      end
  end
end
