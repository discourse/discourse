# frozen_string_literal: true

RSpec.describe FormTemplate::FieldValues do
  describe "#answers" do
    it "preserves typed values, empty values, and rich text" do
      fields = [
        { "id" => "confirmed", "type" => "checkbox" },
        { "id" => "optional", "type" => "checkbox" },
        { "id" => "seats", "type" => "input", "validations" => { "type" => "number" } },
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
        "seats" => "1e2",
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
  end

  describe "#well_formed?" do
    it "accepts tag selections as scalar or collection values" do
      fields = [
        { "id" => "game", "type" => "tag-chooser" },
        { "id" => "cities", "type" => "tag-chooser", "attributes" => { "multiple" => true } },
      ]
      answers = { "game" => "dune", "cities" => %w[campinas paulinia] }

      expect(described_class.new(fields:, answers:)).to be_well_formed
    end

    it "accepts browser strings for numeric dropdown and multi-select choices" do
      fields = [
        { "id" => "choice", "type" => "dropdown", "choices" => [1, 2, 3] },
        { "id" => "choices", "type" => "multi-select", "choices" => [1.0, 1.0e-7] },
      ]
      answers = { "choice" => "2", "choices" => %w[1 1e-7] }

      expect(described_class.new(fields:, answers:)).to be_well_formed
    end

    it "accepts numbers in any spelling the number control accepts" do
      field = { "id" => "seats", "type" => "input", "validations" => { "type" => "number" } }

      [
        "",
        "0",
        "-1",
        "2.5",
        ".5",
        "-.5",
        ".5e+2",
        "1e2",
        "1E-7",
        "12345678901234567890",
      ].each do |value|
        expect(described_class.new(fields: [field], answers: { "seats" => value })).to(
          be_well_formed,
          "expected #{value.inspect} to be accepted",
        )
      end
    end

    it "rejects malformed and nonfinite numeric strings" do
      field = { "id" => "seats", "type" => "input", "validations" => { "type" => "number" } }

      %w[5. -5. 5.e2 . 1e +1 1_000 0x10 NaN Infinity 1e400].each do |value|
        expect(described_class.new(fields: [field], answers: { "seats" => value })).not_to(
          be_well_formed,
          "expected #{value.inspect} to be rejected",
        )
      end
    end

    it "bounds numeric strings before parsing" do
      field = { "id" => "seats", "type" => "input", "validations" => { "type" => "number" } }
      limit = described_class::MAX_NUMBER_LENGTH

      expect(described_class.new(fields: [field], answers: { "seats" => "0" * limit })).to(
        be_well_formed,
      )

      ["0" * (limit + 1), "1" * 1_000_000 + "x"].each do |value|
        expect(described_class.new(fields: [field], answers: { "seats" => value })).not_to(
          be_well_formed,
        )
      end
    end

    it "rejects unknown fields" do
      expect(described_class.new(fields: [], answers: { "unknown" => "value" })).not_to(
        be_well_formed,
      )
    end

    it "rejects values that do not match the control type" do
      [
        [{ "id" => "field", "type" => "checkbox" }, "false"],
        [{ "id" => "field", "type" => "input", "validations" => { "type" => "number" } }, 0],
        [{ "id" => "field", "type" => "input", "validations" => { "type" => "number" } }, "abc"],
        [{ "id" => "field", "type" => "input", "validations" => { "type" => "number" } }, "1e400"],
        [{ "id" => "field", "type" => "multi-select" }, "one\ntwo"],
        [{ "id" => "field", "type" => "multi-select" }, ["one", 2]],
        [{ "id" => "field", "type" => "input" }, { "nested" => "value" }],
      ].each do |field, value|
        expect(described_class.new(fields: [field], answers: { "field" => value })).not_to(
          be_well_formed,
          "expected #{value.inspect} to be rejected for #{field["type"]}",
        )
      end
    end
  end

  describe "#incomplete_fields" do
    let(:fields) do
      [{ "id" => "code", "type" => "input", "validations" => { "required" => true } }]
    end

    it "lists required fields without an answer" do
      expect(described_class.new(fields:, answers: { "code" => "ABC" }).incomplete_fields).to(
        be_empty,
      )
      [{}, { "code" => "" }, { "code" => nil }].each do |answers|
        expect(described_class.new(fields:, answers:).incomplete_fields.map { it["id"] }).to eq(
          %w[code],
        )
      end
    end

    it "ignores disabled required fields" do
      fields.first["attributes"] = { "disabled" => true }

      expect(described_class.new(fields:, answers: {}).incomplete_fields).to be_empty
    end
  end
end
