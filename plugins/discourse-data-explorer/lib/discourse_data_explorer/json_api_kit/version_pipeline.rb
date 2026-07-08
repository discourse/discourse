# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # Applies a gap of VersionChanges to a JSON:API document hash at the
    # serialization seam. Documents are symbol-keyed (serializer output).
    # `down` migrates a latest response document to an older shape: the gap is
    # applied newest→oldest, each change transforming the matching resource
    # objects (primary data + included, dispatched by `type`) and then the
    # document itself. See docs/versioning-design.md.
    class VersionPipeline
      class << self
        def down(document, changes)
          return document if changes.blank?

          changes.each do |change|
            transform_resources(document, change, :down)
            change.document_transform(:down)&.call(document)
          end
          document
        end

        private

        def transform_resources(document, change, direction)
          resources(document).each do |resource|
            next unless resource.is_a?(Hash)
            change.transform_for(direction, type: resource[:type].to_s)&.call(resource)
          end
        end

        def resources(document)
          data = document[:data]
          primary = data.is_a?(Array) ? data : [data]
          (primary + Array(document[:included])).compact
        end
      end
    end
  end
end
