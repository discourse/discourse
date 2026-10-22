# frozen_string_literal: true

RSpec.describe FormTemplate::FieldValues do
  describe "#answers" do
    it "preserves typed values, empty values, and rich text" do
      fields = [
        { "id" => "confirmed", "type" => "checkbox" },
        { "id" => "optional", "type" => "checkbox" },
        { "id" => "seats", "type" => "input", "validations" => { "type" => "number" } },
        { "id" => "price", "type" => "input", "validations" => { "type" => "number" } },
        { "id" => "games", "type" => "multi-select" },
        { "id" => "empty-games", "type" => "multi-select" },
        { "id" => "description", "type" => "composer" },
        { "id" => "empty", "type" => "input" },
        { "id" => "null", "type" => "input" },
        { "id" => "missing", "type" => "input" },
      ]
      answers = {
        "confirmed" => true,
        "optional" => false,
        "seats" => 0,
        "price" => 2.5,
        "games" => %w[first second],
        "empty-games" => [],
        "description" => "First paragraph\n\n**Second paragraph**",
        "empty" => "",
        "null" => nil,
      }

      values = described_class.new(fields:, answers:)

      expect(values.answers).to eq(answers)
      expect(values.answers).not_to have_key("missing")
    end

    it "preserves tag selections as scalar or collection values" do
      fields = [
        { "id" => "game", "type" => "tag-chooser" },
        { "id" => "cities", "type" => "tag-chooser", "attributes" => { "multiple" => true } },
      ]
      answers = { "game" => "dune", "cities" => %w[campinas paulinia] }

      expect(described_class.new(fields:, answers:).answers).to eq(answers)
    end

    it "matches numeric YAML field IDs to JSON answer keys without changing the schema" do
      fields = [
        {
          "id" => 1,
          "type" => "input",
          "validations" => {
            "type" => "number",
            "required" => true,
          },
        },
      ]
      values =
        described_class.new(fields:, answers: { "1" => 100 }, number_formats: { "1" => "1e2" })

      expect(values.fields.first["id"]).to eq("1")
      expect(fields.first["id"]).to eq(1)
      expect { values.validate! }.not_to raise_error
      expect(FormTemplate::DefaultRenderer.render(values)).to eq("### undefined\n1e2")
    end

    it "rejects unknown fields" do
      expect { described_class.new(fields: [], answers: { "unknown" => "value" }) }.to raise_error(
        ArgumentError,
        "Unknown field IDs: unknown",
      )
    end

    it "rejects strings masquerading as booleans, numbers, or collections" do
      [
        [{ "id" => "field", "type" => "checkbox" }, "false"],
        [{ "id" => "field", "type" => "input", "validations" => { "type" => "number" } }, "0"],
        [{ "id" => "field", "type" => "multi-select" }, "one\ntwo"],
        [{ "id" => "field", "type" => "multi-select" }, ["one", 2]],
        [{ "id" => "field", "type" => "input" }, { "nested" => "value" }],
      ].each do |field, value|
        expect {
          described_class.new(fields: [field], answers: { "field" => value })
        }.to raise_error(ArgumentError, "Invalid value for field: field")
      end
    end

    it "rejects non-finite numeric values" do
      field = { "id" => "number", "type" => "input", "validations" => { "type" => "number" } }

      [Float::NAN, Float::INFINITY, -Float::INFINITY].each do |value|
        expect {
          described_class.new(fields: [field], answers: { "number" => value })
        }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#validate!" do
    it "checks required answers, lengths, patterns, and choices" do
      fields = [
        {
          "id" => "code",
          "type" => "input",
          "validations" => {
            "required" => true,
            "minimum" => 2,
            "maximum" => 4,
            "pattern" => "[A-Z]+",
          },
        },
        { "id" => "choices", "type" => "multi-select", "choices" => %w[first second] },
      ]
      expect {
        described_class.new(fields:, answers: { "code" => "ABC", "choices" => ["first"] }).validate!
      }.not_to raise_error
      [
        {},
        { "code" => "a" },
        { "code" => "ABCDE" },
        { "code" => "ABC", "choices" => ["unknown"] },
      ].each do |answers|
        expect { described_class.new(fields:, answers:).validate! }.to raise_error(
          FormTemplate::InvalidAnswers,
        )
      end
    end
  end
end
