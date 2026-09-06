# frozen_string_literal: true

RSpec.describe RSpec::Matchers, "#match_node_output_schema" do
  let(:node_class) do
    Class.new do
      def self.name
        "OutputSchemaTestNode"
      end

      def self.output_schemas(_configuration = {}, input_schemas: [])
        [
          {
            "type" => "object",
            "properties" => {
              "profile" => {
                "type" => "object",
                "properties" => {
                  "name" => {
                    "type" => "string",
                  },
                },
                "required" => ["name"],
                "additionalProperties" => false,
              },
            },
            "required" => ["profile"],
            "additionalProperties" => false,
          },
        ]
      end
    end
  end

  it "accepts output with nested symbol keys" do
    output = { profile: { name: "Ada" } }

    expect(output).to match_node_output_schema(node_class)
  end

  it "reports validation details and their schema pointers" do
    output = { profile: { name: 42 } }

    expect do expect(output).to match_node_output_schema(node_class) end.to raise_error(
      RSpec::Expectations::ExpectationNotMetError,
    ) { |error|
      expect(error.message).to include(
        "expected output to match OutputSchemaTestNode's output schema",
        "property '/profile/name' is not of type: string",
        "[schema: /properties/profile/properties/name]",
      )
    }
  end

  it "rejects nodes that resolve an empty output schema" do
    empty_schema_node =
      Class.new do
        def self.name
          "EmptyOutputSchemaTestNode"
        end

        def self.output_schemas(_configuration = {}, input_schemas: [])
          [{}]
        end
      end
    output = {}

    expect do expect(output).to match_node_output_schema(empty_schema_node) end.to raise_error(
      RSpec::Expectations::ExpectationNotMetError,
      "expected EmptyOutputSchemaTestNode to resolve a concrete output schema, but it resolved {}",
    )
  end

  it "forwards the configuration and input schema when resolving the output schema" do
    contextual_node =
      Class.new do
        def self.output_schemas(configuration = {}, input_schemas: [])
          property = configuration.fetch("property")
          property_type = input_schemas.fetch(0).fetch("type")

          [
            {
              "type" => "object",
              "properties" => {
                property => {
                  "type" => property_type,
                },
              },
              "required" => [property],
              "additionalProperties" => false,
            },
          ]
        end
      end
    configuration = { "property" => "count" }
    input_schema = { "type" => "integer" }
    output = { count: 2 }

    expect(output).to match_node_output_schema(
      contextual_node,
      configuration: configuration,
      input_schemas: [input_schema],
    )
  end

  it "rejects non-Hash output" do
    output = [{ profile: { name: "Ada" } }]

    expect do expect(output).to match_node_output_schema(node_class) end.to raise_error(
      RSpec::Expectations::ExpectationNotMetError,
      "expected node output to be a Hash, got Array",
    )
  end
end
