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

  context "with access control input groups" do
    fab!(:group)
    let(:schema) do
      {
        acl: {
          type: :object,
          ui: {
            control: :access_control,
            expression: false,
          },
          control_options: {
            permissions: %w[view edit manage],
          },
        },
      }
    end
    let(:entries) do
      [
        {
          "type" => "group",
          "id" => group.id,
          "permission" => "view",
          "name" => "={{ $json.name }}",
        },
      ]
    end
    let(:parameters) do
      {
        "acl" => {
          "entries" => entries,
          "group_ids" => "={{ $json.groups }}",
          "permission" => "edit",
        },
      }
    end
    let(:items) { [{ "json" => { "groups" => [group.id, group.id] } }] }

    it "keeps fixed entries literal and gives them precedence over input groups" do
      expect(resolver.resolve("acl")).to eq(entries)
    end

    it "continues accepting saved fixed-only arrays" do
      parameters["acl"] = entries
      expect(resolver.resolve("acl")).to eq(entries)
    end

    it "resolves input groups with default control options" do
      schema[:acl].delete(:control_options)
      parameters["acl"]["entries"] = []

      expect(resolver.resolve("acl")).to eq(
        [{ "type" => "group", "id" => group.id, "permission" => "edit" }],
      )
    end

    it "resolves input groups when whole-field expressions are disabled" do
      schema[:acl][:no_data_expression] = true
      parameters["acl"]["entries"] = []

      expect(resolver.resolve("acl")).to eq(
        [{ "type" => "group", "id" => group.id, "permission" => "edit" }],
      )
    end

    it "rejects results that are not arrays of integer IDs" do
      [nil, false, group.id, group.id.to_s, [group.id.to_s], [-1], [1.5], [{}]].each do |invalid|
        items.first["json"]["groups"] = invalid
        expect { resolver.resolve("acl") }.to raise_error(
          DiscourseWorkflows::NodeError,
          I18n.t("discourse_workflows.errors.access_control.invalid_groups"),
        )
      end
    end

    it "rejects IDs for deleted groups" do
      deleted_group = Fabricate(:group)
      deleted_group.destroy!
      parameters["acl"]["group_ids"] = [deleted_group.id]
      expect { resolver.resolve("acl") }.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t("discourse_workflows.errors.access_control.missing_groups"),
      )
    end

    it "keeps the selected permission literal for the resource service to validate" do
      parameters["acl"]["entries"] = []
      parameters["acl"]["permission"] = "={{ 'manage' }}"

      expect(resolver.resolve("acl")).to eq(
        [{ "type" => "group", "id" => group.id, "permission" => "={{ 'manage' }}" }],
      )
    end

    it "enforces required permissions after resolving an empty input" do
      schema[:acl][:control_options].merge!(required_permissions: ["edit"])
      parameters["acl"]["entries"] = []
      parameters["acl"]["group_ids"] = []
      expect { resolver.resolve("acl") }.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t(
          "discourse_workflows.errors.access_control.required_permission",
          permissions: "edit",
        ),
      )
    end

    it "accepts blank input without adding groups" do
      parameters["acl"]["group_ids"] = ""
      expect(resolver.resolve("acl")).to eq(entries)
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
