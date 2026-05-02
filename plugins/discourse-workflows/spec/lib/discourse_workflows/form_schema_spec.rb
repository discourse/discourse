# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::FormSchema do
  def node(*fields)
    { "configuration" => { "form_fields" => fields } }
  end

  describe ".validate" do
    it "returns valid result with coerced data when all fields are valid" do
      schema =
        node(
          { "field_label" => "Name", "field_type" => "text" },
          { "field_label" => "Age", "field_type" => "number" },
          { "field_label" => "Subscribe", "field_type" => "checkbox" },
        )

      result =
        described_class.validate(
          schema,
          { "name" => "Joffrey", "age" => "42", "subscribe" => "true" },
        )

      expect(result).to be_valid
      expect(result.errors).to be_empty
      expect(result.data).to eq("name" => "Joffrey", "age" => 42, "subscribe" => true)
    end

    it "treats values with a decimal as floats and integers otherwise" do
      schema = node({ "field_label" => "Amount", "field_type" => "number" })

      result = described_class.validate(schema, { "amount" => "12.5" })

      expect(result).to be_valid
      expect(result.data["amount"]).to eq(12.5)
      expect(result.data["amount"]).to be_a(Float)
    end

    it "leaves blank optional number fields out without error" do
      schema = node({ "field_label" => "Age", "field_type" => "number", "required" => false })

      result = described_class.validate(schema, { "age" => "" })

      expect(result).to be_valid
      expect(result.data["age"]).to be_nil
    end

    it "truncates long string field values" do
      schema = node({ "field_label" => "Feedback", "field_type" => "text" })

      result = described_class.validate(schema, { "feedback" => "a" * 10_001 })

      expect(result).to be_valid
      expect(result.data["feedback"].length).to eq(described_class::MAX_FIELD_VALUE_LENGTH)
    end

    it "reports missing required fields" do
      schema =
        node(
          { "field_label" => "Name", "field_type" => "text", "required" => true },
          { "field_label" => "Age", "field_type" => "number", "required" => true },
        )

      result = described_class.validate(schema, { "name" => "" })

      expect(result).not_to be_valid
      expect(result.errors).to contain_exactly(
        described_class::Error.new(field_label: "Name", code: :missing),
        described_class::Error.new(field_label: "Age", code: :missing),
      )
    end

    it "does not flag required checkboxes as missing when blank" do
      schema = node({ "field_label" => "Agree", "field_type" => "checkbox", "required" => true })

      result = described_class.validate(schema, { "agree" => "false" })

      expect(result).to be_valid
      expect(result.data["agree"]).to be(false)
    end

    it "does not flag required checkboxes as missing when key is absent" do
      schema = node({ "field_label" => "Agree", "field_type" => "checkbox", "required" => true })

      result = described_class.validate(schema, {})

      expect(result).to be_valid
    end

    it "reports invalid number values without raising" do
      schema = node({ "field_label" => "Age", "field_type" => "number", "required" => true })

      result = described_class.validate(schema, { "age" => "abc" })

      expect(result).not_to be_valid
      expect(result.errors).to contain_exactly(
        described_class::Error.new(field_label: "Age", code: :invalid_value),
      )
    end

    it "reports invalid number values when the input is a hash or array" do
      schema = node({ "field_label" => "Age", "field_type" => "number" })

      [{ "age" => { "nested" => 1 } }, { "age" => [1, 2] }].each do |params|
        result = described_class.validate(schema, params)
        expect(result).not_to be_valid
        expect(result.errors.first.code).to eq(:invalid_value)
      end
    end

    it "combines missing and invalid errors in one pass" do
      schema =
        node(
          { "field_label" => "Name", "field_type" => "text", "required" => true },
          { "field_label" => "Age", "field_type" => "number", "required" => true },
        )

      result = described_class.validate(schema, { "name" => "", "age" => "abc" })

      expect(result).not_to be_valid
      expect(result.errors.map(&:code)).to contain_exactly(:missing, :invalid_value)
    end

    it "stops coercion of an invalid field but keeps coerced data for the rest" do
      schema =
        node(
          { "field_label" => "Name", "field_type" => "text" },
          { "field_label" => "Age", "field_type" => "number" },
        )

      result = described_class.validate(schema, { "name" => "Joffrey", "age" => "abc" })

      expect(result).not_to be_valid
      expect(result.data).to eq("name" => "Joffrey")
    end

    it "uses field_name when present and falls back to a parameterized label" do
      schema =
        node(
          { "field_label" => "First Name", "field_type" => "text" },
          { "field_label" => "Email", "field_name" => "user_email", "field_type" => "text" },
        )

      result =
        described_class.validate(
          schema,
          { "first_name" => "Joffrey", "user_email" => "j@example.com" },
        )

      expect(result.data).to eq("first_name" => "Joffrey", "user_email" => "j@example.com")
    end

    it "tolerates a node without form_fields configuration" do
      result = described_class.validate({}, { "anything" => "value" })

      expect(result).to be_valid
      expect(result.data).to be_empty
    end

    it "tolerates nil submitted params" do
      schema = node({ "field_label" => "Name", "field_type" => "text" })

      result = described_class.validate(schema, nil)

      expect(result).to be_valid
    end
  end
end
