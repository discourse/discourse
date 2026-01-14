# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::ToolDefinition do
  before { enable_current_plugin }

  # Test case 1: Basic tool definition creation
  describe "#initialize" do
    it "creates a tool with name, description and parameters" do
      param =
        DiscourseAi::Completions::ToolDefinition::ParameterDefinition.new(
          name: "query",
          description: "The search query",
          type: :string,
          required: true,
        )

      tool =
        described_class.new(
          name: "search_engine",
          description: "Searches the web for information",
          parameters: [param],
        )

      expect(tool.name).to eq("search_engine")
      expect(tool.description).to eq("Searches the web for information")
      expect(tool.parameters.size).to eq(1)
      expect(tool.parameters.first.name).to eq("query")
    end
  end

  # Test case 2: Creating tool from hash
  describe ".from_hash" do
    it "creates a tool from a hash representation" do
      hash = {
        name: "calculator",
        description: "Performs math operations",
        parameters: [
          {
            name: "expression",
            description: "Math expression to evaluate",
            type: "string",
            required: true,
          },
        ],
      }

      tool = described_class.from_hash(hash)

      expect(tool.name).to eq("calculator")
      expect(tool.description).to eq("Performs math operations")
      expect(tool.parameters.size).to eq(1)
      expect(tool.parameters.first.name).to eq("expression")
      expect(tool.parameters.first.type).to eq(:string)
    end

    it "rejects a hash with extra keys" do
      hash = {
        name: "calculator",
        description: "Performs math operations",
        parameters: [],
        extra_key: "should not be here",
      }

      expect { described_class.from_hash(hash) }.to raise_error(ArgumentError, /Unexpected keys/)
    end
  end

  # Test case 3: Parameter with enum validation
  describe DiscourseAi::Completions::ToolDefinition::ParameterDefinition do
    context "with enum values" do
      it "accepts valid enum values matching the type" do
        param =
          described_class.new(
            name: "operation",
            description: "Math operation to perform",
            type: :string,
            enum: %w[add subtract multiply divide],
          )

        expect(param.enum).to eq(%w[add subtract multiply divide])
      end

      it "rejects enum values that don't match the specified type" do
        expect {
          described_class.new(
            name: "operation",
            description: "Math operation to perform",
            type: :integer,
            enum: %w[add subtract], # String values for integer type
          )
        }.to raise_error(ArgumentError, /enum values must be integers/)
      end
    end

    context "with item_type specification" do
      it "only allows item_type for array type parameters" do
        expect {
          described_class.new(
            name: "colors",
            description: "List of colors",
            type: :array,
            item_type: :string,
          )
        }.not_to raise_error

        expect {
          described_class.new(
            name: "color",
            description: "A single color",
            type: :string,
            item_type: :string,
          )
        }.to raise_error(ArgumentError, /item_type can only be specified for array type/)
      end
    end
  end

  # Test case 4: Coercing string parameters
  describe "#coerce_parameters" do
    context "with string parameters" do
      let(:tool) do
        param =
          DiscourseAi::Completions::ToolDefinition::ParameterDefinition.new(
            name: "name",
            description: "User's name",
            type: :string,
          )

        described_class.new(
          name: "greeting",
          description: "Generates a greeting",
          parameters: [param],
        )
      end

      it "converts numbers to strings" do
        result = tool.coerce_parameters(name: 123)
        expect(result[:name]).to eq("123")
      end

      it "converts booleans to strings" do
        result = tool.coerce_parameters(name: true)
        expect(result[:name]).to eq("true")
      end
    end

    # Test case 5: Coercing number parameters
    context "with number parameters" do
      let(:tool) do
        param =
          DiscourseAi::Completions::ToolDefinition::ParameterDefinition.new(
            name: "price",
            description: "Item price",
            type: :number,
          )

        described_class.new(name: "store", description: "Store operations", parameters: [param])
      end

      it "converts string numbers to floats" do
        result = tool.coerce_parameters(price: "42.99")
        expect(result[:price]).to eq(42.99)
      end

      it "converts integers to floats" do
        result = tool.coerce_parameters(price: 42)
        expect(result[:price]).to eq(42.0)
      end

      it "returns nil for invalid number strings" do
        result = tool.coerce_parameters(price: "not a number")
        expect(result[:price]).to be_nil
      end
    end

    # Test case 6: Coercing array parameters with item types
    context "with array parameters and item types" do
      let(:tool) do
        param =
          DiscourseAi::Completions::ToolDefinition::ParameterDefinition.new(
            name: "numbers",
            description: "List of numeric values",
            type: :array,
            item_type: :integer,
          )

        described_class.new(
          name: "stats",
          description: "Statistical operations",
          parameters: [param],
        )
      end

      it "converts string elements to integers" do
        result = tool.coerce_parameters(numbers: %w[1 2 3])
        expect(result[:numbers]).to eq([1, 2, 3])
      end

      it "parses JSON strings into arrays and converts elements" do
        result = tool.coerce_parameters(numbers: "[1, 2, 3]")
        expect(result[:numbers]).to eq([1, 2, 3])
      end

      it "handles mixed type arrays appropriately" do
        result = tool.coerce_parameters(numbers: [1, "two", 3.5])
        expect(result[:numbers]).to eq([1, nil, 3])
      end
    end

    # Test case 7: Required parameters
    context "with required and optional parameters" do
      let(:tool) do
        param1 =
          DiscourseAi::Completions::ToolDefinition::ParameterDefinition.new(
            name: "required_param",
            description: "This is required",
            type: :string,
            required: true,
          )

        param2 =
          DiscourseAi::Completions::ToolDefinition::ParameterDefinition.new(
            name: "optional_param",
            description: "This is optional",
            type: :string,
          )

        described_class.new(
          name: "test_tool",
          description: "Test tool",
          parameters: [param1, param2],
        )
      end

      it "includes missing required parameters as nil" do
        result = tool.coerce_parameters(optional_param: "value")
        expect(result[:required_param]).to be_nil
        expect(result[:optional_param]).to eq("value")
      end

      it "skips missing optional parameters" do
        result = tool.coerce_parameters({})
        expect(result[:required_param]).to be_nil
        expect(result.key?("optional_param")).to be false
      end
    end

    # Test case 8: Boolean parameter coercion
    context "with boolean parameters" do
      let(:tool) do
        param =
          DiscourseAi::Completions::ToolDefinition::ParameterDefinition.new(
            name: "flag",
            description: "Boolean flag",
            type: :boolean,
          )

        described_class.new(name: "feature", description: "Feature toggle", parameters: [param])
      end

      it "preserves true/false values" do
        result = tool.coerce_parameters(flag: true)
        expect(result[:flag]).to be true
      end

      it "converts 'true'/'false' strings to booleans" do
        result = tool.coerce_parameters({ flag: true })
        expect(result[:flag]).to be true

        result = tool.coerce_parameters({ flag: "False" })
        expect(result[:flag]).to be false
      end

      it "returns nil for invalid boolean strings" do
        result = tool.coerce_parameters({ "flag" => "not a boolean" })
        expect(result["flag"]).to be_nil
      end
    end
  end

  # Test case 9: Duplicate parameter validation
  describe "duplicate parameter validation" do
    it "rejects tool definitions with duplicate parameter names" do
      param1 =
        DiscourseAi::Completions::ToolDefinition::ParameterDefinition.new(
          name: "query",
          description: "Search query",
          type: :string,
        )

      param2 =
        DiscourseAi::Completions::ToolDefinition::ParameterDefinition.new(
          name: "query", # Same name as param1
          description: "Another parameter",
          type: :string,
        )

      expect {
        described_class.new(
          name: "search",
          description: "Search tool",
          parameters: [param1, param2],
        )
      }.to raise_error(ArgumentError, /Duplicate parameter names/)
    end
  end

  # Test case 10: Serialization to hash
  describe "#to_h" do
    it "serializes the tool to a hash with all properties" do
      param =
        DiscourseAi::Completions::ToolDefinition::ParameterDefinition.new(
          name: "colors",
          description: "List of colors",
          type: :array,
          item_type: :string,
          required: true,
        )

      tool =
        described_class.new(
          name: "palette",
          description: "Color palette generator",
          parameters: [param],
        )

      hash = tool.to_h

      expect(hash[:name]).to eq("palette")
      expect(hash[:description]).to eq("Color palette generator")
      expect(hash[:parameters].size).to eq(1)

      param_hash = hash[:parameters].first
      expect(param_hash[:name]).to eq("colors")
      expect(param_hash[:type]).to eq(:array)
      expect(param_hash[:item_type]).to eq(:string)
      expect(param_hash[:required]).to eq(true)
    end
  end
end
