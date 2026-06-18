# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonapiRb
    # Monkeypatch for jsonapi-serializer 2.2.0 (feature-dead — a stable patch target).
    #
    # Bug: SerializationCore.get_included_records builds each *nested* resource's
    # `record_hash` with the PARENT's parsed include list instead of the child's own, so the
    # child's relationships are never flagged "included". Harmless for normal relationships
    # (their linkage is emitted unconditionally), but with `lazy_load_data: true` it drops the
    # nested-leaf relationship's linkage entirely → resources land in `included` with nothing
    # linking to them (a JSON:API full-linkage violation). Fix: pass the child's own parsed
    # include context (`parse_includes_list(include_item.last)`).
    #
    # This is the thin-layers analogue of the Graphiti monkeypatches: deep nested includes
    # *and* the conditional-linkage perf optimization, together, require this small owned
    # patch. Verbatim copy of the gem's method with one changed line (safe to own — the gem
    # is dormant/frozen). See docs/api-modernization-exploration.md, Part 9.
    module LazyNestedLinkagePatch
      def get_included_records(
        record,
        includes_list,
        known_included_objects,
        fieldsets,
        params = {}
      )
        return if includes_list.blank?
        return [] unless relationships_to_serialize

        includes_list = parse_includes_list(includes_list)

        includes_list.each_with_object([]) do |include_item, included_records|
          relationship_item = relationships_to_serialize[include_item.first]
          next unless relationship_item&.include_relationship?(record, params)

          included_objects = Array(relationship_item.fetch_associated_object(record, params))
          next if included_objects.empty?

          static_serializer = relationship_item.static_serializer
          static_record_type = relationship_item.static_record_type

          included_objects.each do |inc_obj|
            serializer = static_serializer || relationship_item.serializer_for(inc_obj, params)
            record_type = static_record_type || serializer.record_type

            if include_item.last.any?
              serializer_records =
                serializer.get_included_records(
                  inc_obj,
                  include_item.last,
                  known_included_objects,
                  fieldsets,
                  params,
                )
              included_records.concat(serializer_records) unless serializer_records.empty?
            end

            code = "#{record_type}_#{serializer.id_from_record(inc_obj, params)}"
            next if known_included_objects.include?(code)

            known_included_objects << code

            # FIX (vs upstream): the child's OWN include context, not the parent's `includes_list`.
            child_includes = parse_includes_list(include_item.last)
            included_records << serializer.record_hash(
              inc_obj,
              fieldsets[record_type],
              child_includes,
              params,
            )
          end
        end
      end
    end
  end
end
