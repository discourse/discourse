# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::ParameterResolver do
  let(:runtime_state) { DiscourseWorkflows::Executor::NodeExecutionContext::RuntimeState.new }

  def build_resolver(parameters, schema: {}, items: [{ "json" => {} }])
    resolver_context = { "$json" => items.first.fetch("json") { {} } }
    sandbox = DiscourseWorkflows::JsSandbox.new(resolver_context)
    expression_resolver =
      DiscourseWorkflows::ExpressionResolver.new(resolver_context, sandbox: sandbox)
    parameter_resolver =
      described_class.new(
        parameters: parameters,
        property_schema: schema,
        resolver: expression_resolver,
        input_items: items,
        runtime_state: runtime_state,
      )

    [parameter_resolver, expression_resolver, sandbox]
  end

  it "resolves nested paths, defaults, and raw expressions" do
    resolver, expression_resolver, sandbox =
      build_resolver(
        { "outer" => { "inner" => "={{ $json.value }}" }, "count" => "={{ $json.count }}" },
        items: [{ "json" => { "value" => "resolved", "count" => "4" } }],
      )

    expect(resolver.resolve("outer.inner", 0)).to eq("resolved")
    expect(resolver.resolve("outer.missing", 0, default: "fallback")).to eq("fallback")
    expect(resolver.resolve("outer.inner", 0, options: { raw_expressions: true })).to eq(
      "={{ $json.value }}",
    )
  ensure
    expression_resolver&.dispose
    sandbox&.dispose
  end

  it "keeps no_data_expression values literal" do
    resolver, expression_resolver, sandbox =
      build_resolver(
        { "code" => "={{ $json.value }}" },
        schema: {
          code: {
            type: :string,
            no_data_expression: true,
          },
        },
        items: [{ "json" => { "value" => "resolved" } }],
      )

    expect(resolver.resolve("code", 0)).to eq("={{ $json.value }}")
  ensure
    expression_resolver&.dispose
    sandbox&.dispose
  end

  it "resolves condition-builder parameters and records condition metadata" do
    resolver, expression_resolver, sandbox =
      build_resolver(
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
        },
        schema: {
          conditions: {
            ui: {
              control: :condition_builder,
            },
          },
        },
        items: [{ "json" => { "status" => "open" } }],
      )

    expect(resolver.resolve(:conditions, 0)).to eq(true)
    expect(runtime_state.step_metadata["conditions"]).to contain_exactly(
      include("left" => "open", "right" => "open", "passed" => true),
    )
  ensure
    expression_resolver&.dispose
    sandbox&.dispose
  end

  it "resolves fixed collection rows with their nested schemas" do
    resolver, expression_resolver, sandbox =
      build_resolver(
        {
          "fields" => {
            "values" => [{ "name" => "={{ $json.name }}", "literal" => "={{ $json.name }}" }],
          },
        },
        schema: {
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
        },
        items: [{ "json" => { "name" => "Ada" } }],
      )

    expect(resolver.resolve("fields.values", 0)).to eq(
      [{ "name" => "Ada", "literal" => "={{ $json.name }}" }],
    )
  ensure
    expression_resolver&.dispose
    sandbox&.dispose
  end

  it "coerces boolean values using the property schema" do
    resolver, expression_resolver, sandbox =
      build_resolver(
        {
          "enabled" => "={{ $json.enabled }}",
          "disabled" => "false",
          "nested" => {
            "enabled" => "1",
          },
        },
        schema: {
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
        },
        items: [{ "json" => { "enabled" => "true" } }],
      )

    expect(resolver.resolve("enabled", 0)).to eq(true)
    expect(resolver.resolve("disabled", 0)).to eq(false)
    expect(resolver.resolve("nested.enabled", 0)).to eq(true)
  ensure
    expression_resolver&.dispose
    sandbox&.dispose
  end
end
