# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::ParameterResolver do
  subject(:resolver) do
    described_class.new(
      parameters: parameters,
      property_schema: schema,
      resolver: expression_resolver,
      input_items: items,
      runtime_state: runtime_state,
    )
  end

  let(:runtime_state) { DiscourseWorkflows::Executor::NodeExecutionContext::RuntimeState.new }
  let(:schema) { {} }
  let(:items) { [{ "json" => {} }] }
  let(:resolver_context) { { "$json" => items.first.fetch("json") { {} } } }
  let(:sandbox) { DiscourseWorkflows::JsSandbox.new(resolver_context) }
  let(:expression_resolver) do
    DiscourseWorkflows::ExpressionResolver.new(resolver_context, sandbox: sandbox)
  end

  after do
    expression_resolver.dispose
    sandbox.dispose
  end

  context "with nested parameters" do
    let(:parameters) do
      { "outer" => { "inner" => "={{ $json.value }}" }, "count" => "={{ $json.count }}" }
    end
    let(:items) { [{ "json" => { "value" => "resolved", "count" => "4" } }] }

    it "resolves paths, defaults, and raw expressions" do
      expect(resolver.resolve("outer.inner", 0)).to eq("resolved")
      expect(resolver.resolve("outer.missing", 0, default: "fallback")).to eq("fallback")
      expect(resolver.resolve("outer.inner", 0, options: { raw_expressions: true })).to eq(
        "={{ $json.value }}",
      )
    end
  end

  context "with a no_data_expression field" do
    let(:parameters) { { "code" => "={{ $json.value }}" } }
    let(:schema) { { code: { type: :string, no_data_expression: true } } }
    let(:items) { [{ "json" => { "value" => "resolved" } }] }

    it "keeps its value literal" do
      expect(resolver.resolve("code", 0)).to eq("={{ $json.value }}")
    end
  end

  context "with condition-builder parameters" do
    let(:parameters) do
      {
        "conditions" => [
          {
            "leftValue" => "={{ $json.status }}",
            "operator" => {
              "type" => "string",
              "operation" => "equals",
            },
            "rightValue" => "open",
          },
        ],
      }
    end
    let(:schema) { { conditions: { ui: { control: :condition_builder } } } }
    let(:items) { [{ "json" => { "status" => "open" } }] }

    it "resolves them and records condition metadata" do
      expect(resolver.resolve(:conditions, 0)).to eq(true)
      expect(runtime_state.step_metadata["conditions"]).to contain_exactly(
        include("left" => "open", "right" => "open", "passed" => true),
      )
    end
  end

  context "with fixed collection rows" do
    let(:parameters) do
      {
        "fields" => {
          "values" => [{ "name" => "={{ $json.name }}", "literal" => "={{ $json.name }}" }],
        },
      }
    end
    let(:schema) do
      {
        fields: {
          type: :fixed_collection,
          options: [
            {
              name: "values",
              values: {
                name: {
                  type: :string,
                },
                literal: {
                  type: :string,
                  no_data_expression: true,
                },
              },
            },
          ],
        },
      }
    end
    let(:items) { [{ "json" => { "name" => "Ada" } }] }

    it "resolves rows with their nested schemas" do
      expect(resolver.resolve("fields.values", 0)).to eq(
        [{ "name" => "Ada", "literal" => "={{ $json.name }}" }],
      )
    end
  end

  context "with collection option values" do
    let(:parameters) do
      { "updates" => { "title" => "={{ $json.title }}", "trust_level_locked" => "false" } }
    end
    let(:schema) do
      {
        updates: {
          type: :collection,
          options: [
            { name: "title", type: :string },
            { name: "trust_level_locked", type: :boolean },
          ],
        },
      }
    end
    let(:items) { [{ "json" => { "title" => "Member" } }] }

    it "resolves them with their option schemas" do
      expect(resolver.resolve("updates", 0)).to eq(
        "title" => "Member",
        "trust_level_locked" => false,
      )
    end
  end

  context "with boolean fields" do
    let(:parameters) do
      {
        "enabled" => "={{ $json.enabled }}",
        "disabled" => "false",
        "nested" => {
          "enabled" => "1",
        },
      }
    end
    let(:schema) do
      {
        enabled: {
          type: :boolean,
        },
        disabled: {
          type: :boolean,
        },
        nested: {
          type: :object,
          fields: {
            enabled: {
              type: :boolean,
            },
          },
        },
      }
    end
    let(:items) { [{ "json" => { "enabled" => "true" } }] }

    it "coerces values using the property schema" do
      expect(resolver.resolve("enabled", 0)).to eq(true)
      expect(resolver.resolve("disabled", 0)).to eq(false)
      expect(resolver.resolve("nested.enabled", 0)).to eq(true)
    end
  end
end
