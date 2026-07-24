# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Schemas::FormFields do
  describe ".with_keys" do
    it "uses field_name when present and falls back to a parameterized label" do
      fields =
        described_class.with_keys(
          [
            { "field_label" => "First Name", "field_type" => "text" },
            { "field_label" => "Email", "field_name" => "user_email", "field_type" => "text" },
          ],
        )

      expect(fields.map { |field| field["key"] }).to eq(%w[first_name user_email])
    end
  end

  describe ".validate_submission" do
    it "returns valid result with coerced data when all fields are valid" do
      fields = [
        { "field_label" => "Name", "field_type" => "text" },
        { "field_label" => "Age", "field_type" => "number" },
        { "field_label" => "Subscribe", "field_type" => "checkbox" },
      ]

      result =
        described_class.validate_submission(
          fields,
          { "name" => "Joffrey", "age" => "42", "subscribe" => "true" },
        )

      expect(result).to be_valid
      expect(result.errors).to be_empty
      expect(result.data).to eq("name" => "Joffrey", "age" => 42, "subscribe" => true)
    end

    it "treats values with a decimal as floats and integers otherwise" do
      result =
        described_class.validate_submission(
          [{ "field_label" => "Amount", "field_type" => "number" }],
          { "amount" => "12.5" },
        )

      expect(result).to be_valid
      expect(result.data["amount"]).to eq(12.5)
      expect(result.data["amount"]).to be_a(Float)
    end

    it "leaves blank optional number fields out without error" do
      result =
        described_class.validate_submission(
          [{ "field_label" => "Age", "field_type" => "number", "required" => false }],
          { "age" => "" },
        )

      expect(result).to be_valid
      expect(result.data["age"]).to be_nil
    end

    it "truncates long string field values" do
      result =
        described_class.validate_submission(
          [{ "field_label" => "Feedback", "field_type" => "text" }],
          { "feedback" => "a" * 10_001 },
        )

      expect(result).to be_valid
      expect(result.data["feedback"].length).to eq(described_class::MAX_FIELD_VALUE_LENGTH)
    end

    it "reports missing required fields" do
      fields = [
        { "field_label" => "Name", "field_type" => "text", "required" => true },
        { "field_label" => "Age", "field_type" => "number", "required" => true },
      ]

      result = described_class.validate_submission(fields, { "name" => "" })

      expect(result).not_to be_valid
      expect(result.errors).to contain_exactly(
        described_class::ValidationError.new(field_label: "Name", code: :missing),
        described_class::ValidationError.new(field_label: "Age", code: :missing),
      )
    end

    it "does not flag required checkboxes as missing when blank" do
      result =
        described_class.validate_submission(
          [{ "field_label" => "Agree", "field_type" => "checkbox", "required" => true }],
          { "agree" => "false" },
        )

      expect(result).to be_valid
      expect(result.data["agree"]).to be(false)
    end

    it "does not flag required checkboxes as missing when key is absent" do
      result =
        described_class.validate_submission(
          [{ "field_label" => "Agree", "field_type" => "checkbox", "required" => true }],
          {},
        )

      expect(result).to be_valid
    end

    it "reports invalid number values without raising" do
      result =
        described_class.validate_submission(
          [{ "field_label" => "Age", "field_type" => "number", "required" => true }],
          { "age" => "abc" },
        )

      expect(result).not_to be_valid
      expect(result.errors).to contain_exactly(
        described_class::ValidationError.new(field_label: "Age", code: :invalid_value),
      )
    end

    it "reports invalid number values when the input is a hash or array" do
      fields = [{ "field_label" => "Age", "field_type" => "number" }]

      [{ "age" => { "nested" => 1 } }, { "age" => [1, 2] }].each do |params|
        result = described_class.validate_submission(fields, params)
        expect(result).not_to be_valid
        expect(result.errors.first.code).to eq(:invalid_value)
      end
    end

    it "combines missing and invalid errors in one pass" do
      fields = [
        { "field_label" => "Name", "field_type" => "text", "required" => true },
        { "field_label" => "Age", "field_type" => "number", "required" => true },
      ]

      result = described_class.validate_submission(fields, { "name" => "", "age" => "abc" })

      expect(result).not_to be_valid
      expect(result.errors.map(&:code)).to contain_exactly(:missing, :invalid_value)
    end

    it "stops coercion of an invalid field but keeps coerced data for the rest" do
      fields = [
        { "field_label" => "Name", "field_type" => "text" },
        { "field_label" => "Age", "field_type" => "number" },
      ]

      result = described_class.validate_submission(fields, { "name" => "Joffrey", "age" => "abc" })

      expect(result).not_to be_valid
      expect(result.data).to eq("name" => "Joffrey")
    end

    it "uses field names as submission keys when present" do
      fields = [
        { "field_label" => "First Name", "field_type" => "text" },
        { "field_label" => "Email", "field_name" => "user_email", "field_type" => "text" },
      ]

      result =
        described_class.validate_submission(
          fields,
          { "first_name" => "Joffrey", "user_email" => "j@example.com" },
        )

      expect(result.data).to eq("first_name" => "Joffrey", "user_email" => "j@example.com")
    end

    it "supports scalar form field types" do
      fields = [
        { "field_label" => "Email", "field_type" => "email", "required" => true },
        { "field_label" => "Password", "field_type" => "password" },
        { "field_label" => "Start Date", "field_type" => "date" },
        { "field_label" => "Plan", "field_type" => "radio" },
        {
          "field_label" => "Tracking ID",
          "field_type" => "hiddenField",
          "field_value" => "server-value",
        },
        { "field_label" => "Intro", "field_type" => "html", "html" => "<strong>Hello</strong>" },
      ]

      result =
        described_class.validate_submission(
          fields,
          {
            "email" => "a@example.com",
            "password" => "secret",
            "start_date" => "2026-05-18",
            "plan" => "pro",
            "tracking_id" => "client-value",
          },
        )

      expect(result).to be_valid
      expect(result.data).to eq(
        "email" => "a@example.com",
        "password" => "secret",
        "start_date" => "2026-05-18",
        "plan" => "pro",
        "tracking_id" => "server-value",
      )
    end

    it "uses signed query parameters for hidden fields without configured values" do
      fields = [
        { "field_label" => "Tracking ID", "field_type" => "hiddenField", "key" => "tracking_id" },
      ]

      result =
        described_class.validate_submission(
          fields,
          { "tracking_id" => "client-value" },
          query_parameters: {
            "tracking_id" => "query-value",
          },
        )

      expect(result).to be_valid
      expect(result.data).to eq("tracking_id" => "query-value")
    end

    it "reports invalid email values" do
      result =
        described_class.validate_submission(
          [{ "field_label" => "Email", "field_type" => "email" }],
          { "email" => "not-an-email" },
        )

      expect(result).not_to be_valid
      expect(result.errors).to contain_exactly(
        described_class::ValidationError.new(field_label: "Email", code: :invalid_value),
      )
    end

    it "applies query defaults without pre-filling password or HTML fields" do
      fields =
        described_class.with_keys(
          [
            { "field_label" => "Name", "field_type" => "text" },
            { "field_label" => "Password", "field_type" => "password" },
            { "field_label" => "Intro", "field_type" => "html" },
            { "field_label" => "Tracking ID", "field_type" => "hiddenField" },
            {
              "field_label" => "Configured ID",
              "field_type" => "hiddenField",
              "field_value" => "configured",
            },
          ],
        )

      result =
        described_class.apply_query_defaults(
          fields,
          {
            "name" => "Query User",
            "password" => "secret",
            "intro" => "<strong>Query</strong>",
            "tracking_id" => "query-tracking",
            "configured_id" => "query-configured",
          },
        )

      expect(result).to contain_exactly(
        a_hash_including("key" => "name", "default_value" => "Query User"),
        a_hash_including("key" => "password"),
        a_hash_including("key" => "intro"),
        a_hash_including("key" => "tracking_id", "field_value" => "query-tracking"),
        a_hash_including("key" => "configured_id", "field_value" => "configured"),
      )
      expect(result.find { |field| field["key"] == "password" }).not_to have_key("default_value")
      expect(result.find { |field| field["key"] == "intro" }).not_to have_key("default_value")
    end

    it "removes hidden values and password defaults from public fields" do
      fields = [
        {
          "field_label" => "Tracking ID",
          "field_type" => "hiddenField",
          "field_value" => "secret-tracking",
          "default_value" => "old-secret",
        },
        {
          "field_label" => "Password",
          "field_type" => "password",
          "default_value" => "secret-password",
        },
      ]

      expect(described_class.public_fields(fields)).to eq(
        [
          { "field_label" => "Tracking ID", "field_type" => "hiddenField" },
          { "field_label" => "Password", "field_type" => "password" },
        ],
      )
    end

    it "tolerates empty fields" do
      result = described_class.validate_submission([], { "anything" => "value" })

      expect(result).to be_valid
      expect(result.data).to be_empty
    end

    it "tolerates nil submitted params" do
      result =
        described_class.validate_submission(
          [{ "field_label" => "Name", "field_type" => "text" }],
          nil,
        )

      expect(result).to be_valid
    end
  end
end
