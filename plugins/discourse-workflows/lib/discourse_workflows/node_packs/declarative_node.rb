# frozen_string_literal: true

require "json_schemer"

module DiscourseWorkflows
  module NodePacks
    class DeclarativeNode < NodeType
      def self.inherited(subclass)
        super
        NodeType.registered_nodes.delete(subclass)
      end

      def execute(exec_ctx)
        definition = self.class.pack_definition
        request = definition.fetch("request")
        response_definition = definition.fetch("response")
        credential = definition.dig("_effective", "credential")

        items =
          exec_ctx.input_items.flat_map.with_index do |item, item_index|
            params = resolved_parameters(exec_ctx, item_index, definition.fetch("properties"))
            body =
              if request.key?("body")
                TemplateRenderer.render(
                  request["body"],
                  params:,
                  max_bytes: request.fetch("max_request_kb", 256).kilobytes,
                )
              end
            auth_mode = credential_authentication(exec_ctx, credential, item_index)
            approved_origins = Array(definition.dig("_effective", "approved_origins"))
            if approved_origins.empty?
              raise_node_error!(
                I18n.t("discourse_workflows.node_packs.errors.destination_not_approved"),
                item_index: item_index,
              )
            end
            http_response =
              exec_ctx.http_request(
                method: request.fetch("method").downcase.to_sym,
                url: request.fetch("url"),
                headers: request.fetch("headers", {}).merge("Content-Type" => "application/json"),
                body: body.nil? ? nil : JSON.generate(body),
                item_index:,
                options: {
                  "authentication" => auth_mode,
                  "max_retries" => request.dig("retry", "max") || 0,
                  "retry_statuses" => request.dig("retry", "statuses") || [],
                  "max_response_size_kb" => request.fetch("max_response_kb", 1024),
                  "never_error" => false,
                  "redact_error_body" => true,
                  "allowed_origins" => approved_origins,
                },
              )
            output =
              if response_definition.key?("output")
                TemplateRenderer.render(response_definition["output"], response: http_response.body)
              else
                http_response.body
              end
            validate_output!(output)
            output = { "data" => output } unless output.is_a?(Hash)
            [wrap(output, paired_item: exec_ctx.paired_item_for(item))]
          end
        [items]
      end

      private

      def resolved_parameters(exec_ctx, item_index, properties)
        properties.to_h do |name, schema|
          value = exec_ctx.get_node_parameter(name, item_index)
          [name, parse_json_values(value, schema, name, item_index)]
        end
      end

      def parse_json_values(value, schema, path, item_index)
        if schema.dig("ui", "format") == "json" && value.present? && !value.is_a?(Hash) &&
             !value.is_a?(Array)
          JSON.parse(value)
        elsif schema["type"] == "fixed_collection" && value.is_a?(Hash)
          fields = schema.dig("options", 0, "values") || {}
          value.deep_dup.tap do |collection|
            collection.each do |group, rows|
              next unless rows.is_a?(Array)
              collection[group] = rows.map do |row|
                row.to_h do |field, child|
                  [
                    field,
                    parse_json_values(child, fields[field] || {}, "#{path}.#{field}", item_index),
                  ]
                end
              end
            end
          end
        else
          value
        end
      rescue JSON::ParserError
        raise_node_error!(
          I18n.t("discourse_workflows.node_packs.errors.invalid_json_parameter", field: path),
          item_index: item_index,
        )
      end

      def credential_authentication(exec_ctx, credential, item_index)
        return "none" unless credential
        node_credential = exec_ctx.get_node.credentials["auth"]
        unless node_credential
          raise_node_error!(
            I18n.t("discourse_workflows.node_packs.errors.credential_required"),
            item_index: item_index,
          )
        end
        exec_ctx.get_credentials("auth", item_index)
        node_credential["credential_type"]
      end

      def validate_output!(output)
        schemer = self.class.output_schemer
        return if schemer.nil? || schemer.valid?(output)

        raise_node_error!(I18n.t("discourse_workflows.node_packs.errors.response_schema_invalid"))
      end
    end
  end
end

DiscourseWorkflows::NodeType.registered_nodes.delete(DiscourseWorkflows::NodePacks::DeclarativeNode)
