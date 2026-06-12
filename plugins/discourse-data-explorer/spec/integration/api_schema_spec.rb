# frozen_string_literal: true

# Contract guard for the JSON:API spike (see docs/api-modernization-exploration.md).
#
# Generates the Graphiti schema for the plugin's resources and diffs it against
# the committed schema.json. Backwards-incompatible changes (removed attribute/
# filter/sort/relationship, type change, tightened guard, changed default sort,
# page size, removed operator, ...) fail this spec with the exact violations.
#
# To intentionally break the contract (i.e. when bumping the API version), run:
#   FORCE_SCHEMA=true bin/rspec plugins/discourse-data-explorer/spec/integration/api_schema_spec.rb
describe "Data Explorer JSON:API schema contract" do
  let(:schema_path) { Rails.root.join("plugins/discourse-data-explorer/schema.json") }
  let(:resources) do
    [
      DiscourseDataExplorer::QueryResource,
      DiscourseDataExplorer::UserResource,
      DiscourseDataExplorer::GroupResource,
    ]
  end
  let(:current_schema) { Graphiti::Schema.new(resources).generate }

  it "stays backwards-compatible with the committed schema" do
    if File.exist?(schema_path) && ENV["FORCE_SCHEMA"] != "true"
      committed = JSON.parse(File.read(schema_path))
      breaking_changes = Graphiti::SchemaDiff.new(committed, current_schema).compare

      expect(breaking_changes).to be_empty, <<~MSG
        Breaking JSON:API schema changes detected:

        #{breaking_changes.map { "  - #{it}" }.join("\n")}

        If this is intentional, this is a new major API version: regenerate the
        schema with FORCE_SCHEMA=true and coordinate the version bump.
      MSG
    end

    File.write(schema_path, JSON.pretty_generate(current_schema))
  end
end
