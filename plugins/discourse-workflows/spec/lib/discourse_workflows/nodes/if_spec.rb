# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::If::V1 do
  def build_config(conditions:, combinator: "and", options: {})
    { "conditions" => conditions, "combinator" => combinator, "options" => options }
  end

  def build_condition(configuration)
    described_class.new(configuration: configuration)
  end

  def wrap_items(*jsons)
    jsons.map { |json| { "json" => json } }
  end

  def build_exec_ctx(items, configuration: {}, resolver: nil)
    resolver ||=
      DiscourseWorkflows::ExpressionResolver.new({ "$json" => items.first&.dig("json") || {} })
    DiscourseWorkflows::NodeExecutionContext.new(
      input_items: items,
      configuration: configuration,
      configuration_schema: described_class.configuration_schema,
      resolver: resolver,
    )
  end

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("condition:if")
    end
  end

  describe ".property_i18n_scope" do
    it "is inferred from identifier" do
      expect(described_class.property_i18n_scope).to eq("if")
    end
  end

  describe ".outputs" do
    it "defines explicit true and false outputs" do
      expect(described_class.outputs).to eq(
        [
          { key: "true", label_key: "discourse_workflows.branch.true" },
          { key: "false", label_key: "discourse_workflows.branch.false" },
        ],
      )
    end
  end

  describe "#execute" do
    context "with combinators" do
      it "and: all conditions must pass" do
        config =
          build_config(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "={{ $json.status }}",
                "rightValue" => "closed",
                "operator" => {
                  "type" => "string",
                  "operation" => "equals",
                },
              },
              {
                "id" => "2",
                "leftValue" => "={{ $json.enabled }}",
                "operator" => {
                  "type" => "boolean",
                  "operation" => "true",
                  "singleValue" => true,
                },
              },
            ],
            combinator: "and",
          )
        condition = build_condition(config)

        items = wrap_items({ "status" => "closed", "enabled" => true })
        result = condition.execute(build_exec_ctx(items, configuration: config))
        expect(result[0]).to eq(items)

        items = wrap_items({ "status" => "closed", "enabled" => false })
        result = condition.execute(build_exec_ctx(items, configuration: config))
        expect(result[1]).to eq(items)
      end

      it "or: any condition passing is enough" do
        config =
          build_config(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "={{ $json.status }}",
                "rightValue" => "closed",
                "operator" => {
                  "type" => "string",
                  "operation" => "equals",
                },
              },
              {
                "id" => "2",
                "leftValue" => "={{ $json.status }}",
                "rightValue" => "archived",
                "operator" => {
                  "type" => "string",
                  "operation" => "equals",
                },
              },
            ],
            combinator: "or",
          )
        condition = build_condition(config)

        items = wrap_items({ "status" => "archived" })
        result = condition.execute(build_exec_ctx(items, configuration: config))
        expect(result[0]).to eq(items)

        items = wrap_items({ "status" => "open" })
        result = condition.execute(build_exec_ctx(items, configuration: config))
        expect(result[1]).to eq(items)
      end
    end

    context "with per-item routing" do
      it "routes items to different outputs based on condition" do
        config =
          build_config(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "={{ $json.status }}",
                "rightValue" => "closed",
                "operator" => {
                  "type" => "string",
                  "operation" => "equals",
                },
              },
            ],
          )
        condition = build_condition(config)

        items = wrap_items({ "status" => "closed", "id" => 1 }, { "status" => "open", "id" => 2 })
        result = condition.execute(build_exec_ctx(items, configuration: config))
        expect(result[0].length).to eq(1)
        expect(result[0].first["json"]["id"]).to eq(1)
        expect(result[1].length).to eq(1)
        expect(result[1].first["json"]["id"]).to eq(2)
      end
    end

    context "with missing context values" do
      it "treats missing fields as nil" do
        config =
          build_config(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "={{ $json.nonexistent }}",
                "rightValue" => "something",
                "operator" => {
                  "type" => "string",
                  "operation" => "equals",
                },
              },
            ],
          )
        condition = build_condition(config)

        items = wrap_items({ "status" => "closed" })
        result = condition.execute(build_exec_ctx(items, configuration: config))
        expect(result[1]).to eq(items)
      end
    end
  end
end
