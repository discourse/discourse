# frozen_string_literal: true

module DiscourseWorkflows
  module NodePacks
    module ClassFactory
      module_function

      def normalize_property_enums!(schema)
        schema.each_value do |field|
          next unless field.is_a?(Hash)
          field[:type] = field[:type]&.to_sym
          field[:ui][:control] = field[:ui][:control]&.to_sym if field[:ui].is_a?(Hash)
          Array(field[:options]).each do |option|
            if option.is_a?(Hash) && option[:values].is_a?(Hash)
              normalize_property_enums!(option[:values])
            end
          end
        end
      end

      def build(definition_record, pack_record)
        definition = definition_record.definition.deep_dup.freeze
        pack_id = pack_record.id
        pack_ui = {
          "key" => pack_record.key,
          "name" => pack_record.name,
          "version" => pack_record.version,
          "icon" => pack_record.manifest["icon"],
        }.freeze
        retired = definition_record.retired_at.present?
        credential = definition.dig("_effective", "credential")
        credentials =
          if credential
            [
              {
                name: "auth",
                credential_types: credential.fetch("credential_types"),
                required: credential.fetch("required"),
                label: credential.fetch("label"),
              },
            ]
          else
            []
          end
        output_schema = definition.dig("response", "output_schema")
        output_schemer = JSONSchemer.schema(output_schema) if output_schema
        output_contracts = output_schema ? [{ schema: output_schema }] : []
        properties = definition.fetch("properties").deep_symbolize_keys
        normalize_property_enums!(properties)

        Class
          .new(DeclarativeNode)
          .tap do |klass|
            klass.description(
              name: definition_record.identifier,
              version: definition_record.version,
              defaults: { icon: definition["icon"], color: definition["color"] }.compact,
              capabilities: {
                run_scope: "per_item",
              },
              properties: properties,
              credentials: credentials,
              output_contracts: output_contracts,
              palette_visible: -> do
                !retired &&
                  NodePack.where(id: pack_id, removed_at: nil, palette_visible: true).exists?
              end,
              available: -> { NodePack.where(id: pack_id, removed_at: nil, enabled: true).exists? },
              unavailable_reason_key: "discourse_workflows.node_packs.pack_disabled",
              previewable: false,
            )
            klass.define_singleton_method(:pack_definition) { definition }
            klass.define_singleton_method(:output_schemer) { output_schemer }
            klass.define_singleton_method(:pack_definition_id) { definition_record.id }
            klass.define_singleton_method(:pack_id) { pack_id }
            klass.define_singleton_method(:imported_node_pack?) { true }
            klass.define_singleton_method(:examples) { definition.fetch("examples", []) }
            klass.define_singleton_method(:label_key) { nil }
            klass.define_singleton_method(:description_key) { nil }
            klass.define_singleton_method(:group) { "pack:#{pack_ui.fetch("key")}" }
            klass.define_singleton_method(:palette_group) do
              {
                id: group,
                label: pack_ui.fetch("name"),
                icon: pack_ui["icon"] || "cubes",
                order: 200 + pack_id,
              }
            end
            klass.define_singleton_method(:ui_metadata) do
              super().merge(
                label: definition.fetch("label"),
                description: definition["description"],
                subtitle: definition["subtitle"],
                docs_url: definition["docs_url"],
                palette_group: palette_group,
                pack: {
                  id: pack_id,
                  key: pack_ui.fetch("key"),
                  name: pack_ui.fetch("name"),
                  version: pack_ui.fetch("version"),
                  definition_version: definition_record.version,
                  retired: retired,
                },
              ).compact
            end
          end
      end
    end
  end
end
