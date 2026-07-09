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
    #
    # Error documents are typeless, so `down_errors` takes the endpoint's primary
    # resource type. Pointer and fieldset rewrites are pure lookups over each
    # change's DECLARED renames — no transform code runs outside a real document.
    class VersionPipeline
      ATTRIBUTE_POINTER = %r{\A/data/attributes/(?<name>[^/]+)\z}

      class << self
        def down(document, changes)
          return document if changes.blank?

          changes.each do |change|
            transform_resources(document, change, :down)
            change.document_transform(:down)&.call(document)
          end
          document
        end

        # `fields[TYPE]` values are attribute names: map them through each change's
        # DECLARED renames, oldest→newest — a pure lookup, no transform code runs.
        # Changes that only have hand-written blocks contribute no mapping (the
        # rule: a change that alters key names must declare them).
        def up_fieldset(names, type:, changes:)
          symbols = names.map(&:to_sym)
          return symbols if changes.blank?

          changes
            .reverse_each
            .reduce(symbols) do |current, change|
              renames = change.field_renames_for(type)
              current.map { renames[it] || it }
            end
        end

        def down_errors(document, type:, changes:)
          return document if changes.blank?

          Array(document[:errors]).each do |error|
            next unless error.is_a?(Hash)
            match = ATTRIBUTE_POINTER.match(error.dig(:source, :pointer).to_s) or next
            downgraded_name = downgrade_attribute_name(match[:name], type, changes)
            error[:source][:pointer] = "/data/attributes/#{downgraded_name}"
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

        # Inverse lookup over each change's declared renames, newest→oldest.
        def downgrade_attribute_name(name, type, changes)
          changes.reduce(name.to_sym) do |current, change|
            change.field_renames_for(type).key(current) || current
          end
        end

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
