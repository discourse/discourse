# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Conditions::IfCondition do
  before { SiteSetting.discourse_workflows_enabled = true }

  def build_condition(conditions:, combinator: "and", options: {})
    described_class.new(
      configuration: {
        "conditions" => conditions,
        "combinator" => combinator,
        "options" => options,
      },
    )
  end

  def wrap_items(*jsons)
    jsons.map { |json| { "json" => json } }
  end

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("condition:if")
    end
  end

  describe "#evaluate" do
    context "with string operators" do
      it "equals" do
        condition =
          build_condition(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "status",
                "rightValue" => "closed",
                "operator" => {
                  "type" => "string",
                  "operation" => "equals",
                },
              },
            ],
          )

        items = wrap_items({ "status" => "closed" })
        result = condition.evaluate(input_items: items)
        expect(result["true"]).to eq(items)
        expect(result["false"]).to eq([])

        items = wrap_items({ "status" => "open" })
        result = condition.evaluate(input_items: items)
        expect(result["true"]).to eq([])
        expect(result["false"]).to eq(items)
      end

      it "notEquals" do
        condition =
          build_condition(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "status",
                "rightValue" => "closed",
                "operator" => {
                  "type" => "string",
                  "operation" => "notEquals",
                },
              },
            ],
          )

        items = wrap_items({ "status" => "open" })
        result = condition.evaluate(input_items: items)
        expect(result["true"]).to eq(items)
      end

      it "contains" do
        condition =
          build_condition(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "status",
                "rightValue" => "los",
                "operator" => {
                  "type" => "string",
                  "operation" => "contains",
                },
              },
            ],
          )

        items = wrap_items({ "status" => "closed" })
        result = condition.evaluate(input_items: items)
        expect(result["true"]).to eq(items)
      end

      it "notContains" do
        condition =
          build_condition(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "status",
                "rightValue" => "xyz",
                "operator" => {
                  "type" => "string",
                  "operation" => "notContains",
                },
              },
            ],
          )

        items = wrap_items({ "status" => "closed" })
        result = condition.evaluate(input_items: items)
        expect(result["true"]).to eq(items)
      end

      it "empty" do
        condition =
          build_condition(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "status",
                "operator" => {
                  "type" => "string",
                  "operation" => "empty",
                  "singleValue" => true,
                },
              },
            ],
          )

        items = wrap_items({ "status" => "" })
        result = condition.evaluate(input_items: items)
        expect(result["true"]).to eq(items)

        items = wrap_items({ "status" => "closed" })
        result = condition.evaluate(input_items: items)
        expect(result["false"]).to eq(items)
      end

      it "notEmpty" do
        condition =
          build_condition(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "status",
                "operator" => {
                  "type" => "string",
                  "operation" => "notEmpty",
                  "singleValue" => true,
                },
              },
            ],
          )

        items = wrap_items({ "status" => "closed" })
        result = condition.evaluate(input_items: items)
        expect(result["true"]).to eq(items)
      end

      it "case insensitive when configured" do
        condition =
          build_condition(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "status",
                "rightValue" => "CLOSED",
                "operator" => {
                  "type" => "string",
                  "operation" => "equals",
                },
              },
            ],
            options: {
              "caseSensitive" => false,
            },
          )

        items = wrap_items({ "status" => "closed" })
        result = condition.evaluate(input_items: items)
        expect(result["true"]).to eq(items)
      end
    end

    context "with number operators" do
      it "equals" do
        condition =
          build_condition(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "topic_id",
                "rightValue" => 42,
                "operator" => {
                  "type" => "number",
                  "operation" => "equals",
                },
              },
            ],
          )

        items = wrap_items({ "topic_id" => 42 })
        result = condition.evaluate(input_items: items)
        expect(result["true"]).to eq(items)
      end

      it "gt" do
        condition =
          build_condition(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "topic_id",
                "rightValue" => 10,
                "operator" => {
                  "type" => "number",
                  "operation" => "gt",
                },
              },
            ],
          )

        items = wrap_items({ "topic_id" => 42 })
        result = condition.evaluate(input_items: items)
        expect(result["true"]).to eq(items)

        items = wrap_items({ "topic_id" => 5 })
        result = condition.evaluate(input_items: items)
        expect(result["false"]).to eq(items)
      end

      it "lt, gte, lte" do
        items = wrap_items({ "value" => 10 })

        lt =
          build_condition(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "value",
                "rightValue" => 20,
                "operator" => {
                  "type" => "number",
                  "operation" => "lt",
                },
              },
            ],
          )
        expect(lt.evaluate(input_items: items)["true"]).to eq(items)

        gte =
          build_condition(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "value",
                "rightValue" => 10,
                "operator" => {
                  "type" => "number",
                  "operation" => "gte",
                },
              },
            ],
          )
        expect(gte.evaluate(input_items: items)["true"]).to eq(items)

        lte =
          build_condition(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "value",
                "rightValue" => 10,
                "operator" => {
                  "type" => "number",
                  "operation" => "lte",
                },
              },
            ],
          )
        expect(lte.evaluate(input_items: items)["true"]).to eq(items)
      end
    end

    context "with boolean operators" do
      it "true" do
        condition =
          build_condition(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "enabled",
                "operator" => {
                  "type" => "boolean",
                  "operation" => "true",
                  "singleValue" => true,
                },
              },
            ],
          )

        items = wrap_items({ "enabled" => true })
        result = condition.evaluate(input_items: items)
        expect(result["true"]).to eq(items)

        items = wrap_items({ "enabled" => false })
        result = condition.evaluate(input_items: items)
        expect(result["false"]).to eq(items)
      end

      it "false" do
        condition =
          build_condition(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "enabled",
                "operator" => {
                  "type" => "boolean",
                  "operation" => "false",
                  "singleValue" => true,
                },
              },
            ],
          )

        items = wrap_items({ "enabled" => false })
        result = condition.evaluate(input_items: items)
        expect(result["true"]).to eq(items)
      end

      it "equals" do
        condition =
          build_condition(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "enabled",
                "rightValue" => true,
                "operator" => {
                  "type" => "boolean",
                  "operation" => "equals",
                },
              },
            ],
          )

        items = wrap_items({ "enabled" => true })
        result = condition.evaluate(input_items: items)
        expect(result["true"]).to eq(items)
      end
    end

    context "with combinators" do
      it "and: all conditions must pass" do
        condition =
          build_condition(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "status",
                "rightValue" => "closed",
                "operator" => {
                  "type" => "string",
                  "operation" => "equals",
                },
              },
              {
                "id" => "2",
                "leftValue" => "enabled",
                "operator" => {
                  "type" => "boolean",
                  "operation" => "true",
                  "singleValue" => true,
                },
              },
            ],
            combinator: "and",
          )

        items = wrap_items({ "status" => "closed", "enabled" => true })
        result = condition.evaluate(input_items: items)
        expect(result["true"]).to eq(items)

        items = wrap_items({ "status" => "closed", "enabled" => false })
        result = condition.evaluate(input_items: items)
        expect(result["false"]).to eq(items)
      end

      it "or: any condition passing is enough" do
        condition =
          build_condition(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "status",
                "rightValue" => "closed",
                "operator" => {
                  "type" => "string",
                  "operation" => "equals",
                },
              },
              {
                "id" => "2",
                "leftValue" => "status",
                "rightValue" => "archived",
                "operator" => {
                  "type" => "string",
                  "operation" => "equals",
                },
              },
            ],
            combinator: "or",
          )

        items = wrap_items({ "status" => "archived" })
        result = condition.evaluate(input_items: items)
        expect(result["true"]).to eq(items)

        items = wrap_items({ "status" => "open" })
        result = condition.evaluate(input_items: items)
        expect(result["false"]).to eq(items)
      end
    end

    context "with per-item routing" do
      it "routes items to different outputs based on condition" do
        condition =
          build_condition(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "status",
                "rightValue" => "closed",
                "operator" => {
                  "type" => "string",
                  "operation" => "equals",
                },
              },
            ],
          )

        items = wrap_items({ "status" => "closed", "id" => 1 }, { "status" => "open", "id" => 2 })
        result = condition.evaluate(input_items: items)
        expect(result["true"].length).to eq(1)
        expect(result["true"].first["json"]["id"]).to eq(1)
        expect(result["false"].length).to eq(1)
        expect(result["false"].first["json"]["id"]).to eq(2)
      end
    end

    context "with missing context values" do
      it "treats missing fields as nil" do
        condition =
          build_condition(
            conditions: [
              {
                "id" => "1",
                "leftValue" => "nonexistent",
                "rightValue" => "something",
                "operator" => {
                  "type" => "string",
                  "operation" => "equals",
                },
              },
            ],
          )

        items = wrap_items({ "status" => "closed" })
        result = condition.evaluate(input_items: items)
        expect(result["false"]).to eq(items)
      end
    end
  end
end
