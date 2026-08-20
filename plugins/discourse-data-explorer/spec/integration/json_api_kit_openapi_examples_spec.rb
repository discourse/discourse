# frozen_string_literal: true

require "json_schemer"

# Committed examples may go stale in VALUES (cosmetic) but never in SHAPE:
# every captured example must validate against its operation's generated
# schema. Operations live in the site document or in a plugin document
# (contribution fragments carry their own operationIds). Recapture with:
#   CAPTURE_API_EXAMPLES=1 bin/rspec plugins/discourse-data-explorer/spec/requests/discourse_data_explorer/json_api_kit/open_api_examples_spec.rb
# then regenerate the documents with `bin/rake data_explorer:json_api_docs`.
RSpec.describe "Data Explorer OpenAPI examples freshness" do
  subject(:offences) do
    committed_examples.flat_map do |operation_id, captures|
      operation, document = find_operation(operation_id)
      captures.flat_map do |status, example|
        schema =
          if status == "request"
            operation.dig("requestBody", "content", "application/vnd.api+json", "schema")
          else
            operation.dig("responses", status, "content", "application/vnd.api+json", "schema")
          end
        JSONSchemer
          .schema(schema.merge("components" => document["components"]))
          .validate(example)
          .to_a
          .map { |result| "#{operation_id} #{status}: #{result["error"]}" }
      end
    end
  end

  let(:documents) do
    [DiscourseDataExplorer::JsonApiKit.openapi_document] +
      DiscourseDataExplorer::JsonApiKit.plugins.keys.sort.map do
        DiscourseDataExplorer::JsonApiKit.openapi_document_for(it)
      end
  end
  let(:committed_examples) do
    JSON.parse(Rails.root.join("plugins/discourse-data-explorer/openapi-examples.json").read)
  end

  def find_operation(operation_id)
    documents.each do |document|
      document["paths"].each_value do |operations|
        operations.each_value do |operation|
          return operation, document if operation["operationId"] == operation_id
        end
      end
    end
    nil
  end

  it "keeps every committed example schema-valid" do
    expect(offences).to eq([])
  end
end
