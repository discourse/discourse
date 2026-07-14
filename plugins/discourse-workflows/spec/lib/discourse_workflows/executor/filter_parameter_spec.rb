# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::FilterParameter do
  describe ".execute_filter" do
    let(:resolver) do
      Class
        .new do
          def resolve(value)
            value
          end
        end
        .new
    end

    it "resolves condition details" do
      result =
        described_class.execute_filter(
          [
            {
              "leftValue" => "closed",
              "rightValue" => "closed",
              "operator" => {
                "type" => "string",
                "operation" => "equals",
                "singleValue" => false,
              },
            },
          ],
          "and",
          {},
          resolver,
        )

      expect(result).to eq(
        "passed" => true,
        "details" => [
          {
            "left" => "closed",
            "leftExpression" => "closed",
            "operator" => "equals",
            "right" => "closed",
            "type" => "string",
            "passed" => true,
          },
        ],
      )
    end
  end

  describe ".evaluate_type" do
    context "with string type" do
      it "equals" do
        expect(described_class.evaluate_type("string", "closed", "closed", "equals", {})).to be(
          true,
        )
        expect(described_class.evaluate_type("string", "closed", "open", "equals", {})).to be(false)
      end

      it "notEquals" do
        expect(described_class.evaluate_type("string", "open", "closed", "notEquals", {})).to be(
          true,
        )
        expect(described_class.evaluate_type("string", "closed", "closed", "notEquals", {})).to be(
          false,
        )
      end

      it "contains" do
        expect(described_class.evaluate_type("string", "closed", "los", "contains", {})).to be(true)
        expect(described_class.evaluate_type("string", "closed", "xyz", "contains", {})).to be(
          false,
        )
      end

      it "notContains" do
        expect(described_class.evaluate_type("string", "closed", "xyz", "notContains", {})).to be(
          true,
        )
        expect(described_class.evaluate_type("string", "closed", "los", "notContains", {})).to be(
          false,
        )
      end

      it "empty" do
        expect(described_class.evaluate_type("string", "", nil, "empty", {})).to be(true)
        expect(described_class.evaluate_type("string", "closed", nil, "empty", {})).to be(false)
      end

      it "notEmpty" do
        expect(described_class.evaluate_type("string", "closed", nil, "notEmpty", {})).to be(true)
        expect(described_class.evaluate_type("string", "", nil, "notEmpty", {})).to be(false)
      end

      it "is case insensitive when configured" do
        options = { "caseSensitive" => false }
        expect(
          described_class.evaluate_type("string", "closed", "CLOSED", "equals", options),
        ).to eq(true)
        expect(
          described_class.evaluate_type("string", "CLOSED", "closed", "equals", options),
        ).to eq(true)
      end

      it "is case sensitive by default" do
        expect(described_class.evaluate_type("string", "closed", "CLOSED", "equals", {})).to be(
          false,
        )
      end

      it "returns false for unknown operations" do
        expect(described_class.evaluate_type("string", "a", "b", "unknown", {})).to be(false)
      end
    end

    context "with number type" do
      it "equals" do
        expect(described_class.evaluate_type("number", 42, 42, "equals", {})).to be(true)
        expect(described_class.evaluate_type("number", 42, 43, "equals", {})).to be(false)
      end

      it "notEquals" do
        expect(described_class.evaluate_type("number", 42, 43, "notEquals", {})).to be(true)
        expect(described_class.evaluate_type("number", 42, 42, "notEquals", {})).to be(false)
      end

      it "gt" do
        expect(described_class.evaluate_type("number", 42, 10, "gt", {})).to be(true)
        expect(described_class.evaluate_type("number", 5, 10, "gt", {})).to be(false)
      end

      it "lt" do
        expect(described_class.evaluate_type("number", 10, 20, "lt", {})).to be(true)
        expect(described_class.evaluate_type("number", 20, 10, "lt", {})).to be(false)
      end

      it "gte" do
        expect(described_class.evaluate_type("number", 10, 10, "gte", {})).to be(true)
        expect(described_class.evaluate_type("number", 11, 10, "gte", {})).to be(true)
        expect(described_class.evaluate_type("number", 9, 10, "gte", {})).to be(false)
      end

      it "lte" do
        expect(described_class.evaluate_type("number", 10, 10, "lte", {})).to be(true)
        expect(described_class.evaluate_type("number", 9, 10, "lte", {})).to be(true)
        expect(described_class.evaluate_type("number", 11, 10, "lte", {})).to be(false)
      end

      it "returns false for unknown operations" do
        expect(described_class.evaluate_type("number", 1, 2, "unknown", {})).to be(false)
      end

      it "handles string numeric values" do
        expect(described_class.evaluate_type("number", "42", "42", "equals", {})).to be(true)
        expect(described_class.evaluate_type("number", "10.5", "5", "gt", {})).to be(true)
      end

      it "returns false when left value is not numeric" do
        expect(described_class.evaluate_type("number", "hello", 42, "equals", {})).to be(false)
        expect(described_class.evaluate_type("number", "hello", 42, "gt", {})).to be(false)
      end

      it "returns false when right value is not numeric" do
        expect(described_class.evaluate_type("number", 42, "hello", "equals", {})).to be(false)
      end

      it "returns false when both values are not numeric" do
        expect(described_class.evaluate_type("number", "foo", "bar", "equals", {})).to be(false)
      end

      it "returns false for nil values" do
        expect(described_class.evaluate_type("number", nil, 42, "equals", {})).to be(false)
        expect(described_class.evaluate_type("number", 42, nil, "equals", {})).to be(false)
      end
    end

    context "with boolean type" do
      it "true" do
        expect(described_class.evaluate_type("boolean", true, nil, "true", {})).to be(true)
        expect(described_class.evaluate_type("boolean", false, nil, "true", {})).to be(false)
      end

      it "false" do
        expect(described_class.evaluate_type("boolean", false, nil, "false", {})).to be(true)
        expect(described_class.evaluate_type("boolean", true, nil, "false", {})).to be(false)
      end

      it "equals" do
        expect(described_class.evaluate_type("boolean", true, true, "equals", {})).to be(true)
        expect(described_class.evaluate_type("boolean", true, false, "equals", {})).to be(false)
      end

      it "notEquals" do
        expect(described_class.evaluate_type("boolean", true, false, "notEquals", {})).to be(true)
        expect(described_class.evaluate_type("boolean", true, true, "notEquals", {})).to be(false)
      end

      it "returns false for unknown operations" do
        expect(described_class.evaluate_type("boolean", true, nil, "unknown", {})).to be(false)
      end
    end

    context "with array type" do
      it "contains" do
        expect(described_class.evaluate_type("array", %w[a b c], "b", "contains", {})).to be(true)
        expect(described_class.evaluate_type("array", %w[a b c], "d", "contains", {})).to be(false)
      end

      it "notContains" do
        expect(described_class.evaluate_type("array", %w[a b c], "d", "notContains", {})).to be(
          true,
        )
        expect(described_class.evaluate_type("array", %w[a b c], "b", "notContains", {})).to be(
          false,
        )
      end

      it "empty" do
        expect(described_class.evaluate_type("array", [], nil, "empty", {})).to be(true)
        expect(described_class.evaluate_type("array", %w[a], nil, "empty", {})).to be(false)
      end

      it "handles nil for empty" do
        expect(described_class.evaluate_type("array", nil, nil, "empty", {})).to be(false)
      end

      it "notEmpty" do
        expect(described_class.evaluate_type("array", %w[a], nil, "notEmpty", {})).to be(true)
        expect(described_class.evaluate_type("array", [], nil, "notEmpty", {})).to be(false)
      end

      it "returns false for unknown operations" do
        expect(described_class.evaluate_type("array", [], nil, "unknown", {})).to be(false)
      end
    end

    context "with unknown type" do
      it "returns false" do
        expect(described_class.evaluate_type("unknown", "a", "b", "equals", {})).to be(false)
      end
    end
  end
end
