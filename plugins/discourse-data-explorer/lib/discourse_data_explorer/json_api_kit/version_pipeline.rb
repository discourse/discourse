# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # Applies a gap of VersionChanges to a JSON:API document hash. Documents are
    # symbol-keyed; both methods take the gap as produced by the registry
    # (newest→oldest). `down` migrates a latest response document to an older
    # shape, applying the gap in that order — each change transforming the
    # matching resource objects (primary data + included, dispatched by `type`)
    # and then the document itself. `up` migrates an old request document to the
    # latest shape: the gap reversed (oldest→newest), each change transforming
    # the document then the resources — the exact inverse of `down`. A resource
    # transform only runs when `attributes` is a hash (request documents are
    # client input). See docs/versioning-design.md.
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

        def up(document, changes)
          return document if changes.blank?

          changes.reverse_each do |change|
            change.document_transform(:up)&.call(document)
            transform_resources(document, change, :up)
          end
          document
        end

        private

        def transform_resources(document, change, direction)
          resources(document).each do |resource|
            next unless resource.is_a?(Hash) && resource[:attributes].is_a?(Hash)
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
