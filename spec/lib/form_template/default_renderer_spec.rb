# frozen_string_literal: true

RSpec.describe FormTemplate::DefaultRenderer do
  describe ".render" do
    it "renders headings, multiline values, selections, checked controls, and zero" do
      fields = [
        { "id" => "description", "type" => "composer", "attributes" => { "label" => "Details" } },
        { "id" => "games", "type" => "multi-select", "attributes" => { "label" => "Games" } },
        { "id" => "checked", "type" => "checkbox", "attributes" => { "label" => "Confirmed" } },
        {
          "id" => "price",
          "type" => "input",
          "attributes" => {
            "label" => "Price",
          },
          "validations" => {
            "type" => "number",
          },
        },
      ]
      values =
        FormTemplate::FieldValues.new(
          fields:,
          answers: {
            "description" => "First line\n\n**Second line**",
            "games" => %w[First Second],
            "checked" => true,
            "price" => "0",
          },
        )

      original_answers = values.answers.deep_dup

      expect(described_class.render(values)).to eq(
        "### Details\nFirst line\n\n**Second line**\n\n### Games\nFirst\nSecond\n\n### Confirmed\non\n\n### Price\n0",
      )
      expect(values.answers).to eq(original_answers)
    end

    it "preserves separators for empty successful controls while omitting unsubmitted controls" do
      fields = [
        { "id" => "first", "type" => "input", "attributes" => { "label" => "First" } },
        { "id" => "empty", "type" => "input" },
        { "id" => "unchecked", "type" => "checkbox" },
        { "id" => "missing", "type" => "input" },
        { "id" => "selections", "type" => "multi-select" },
        { "id" => "null", "type" => "input" },
        { "id" => "last", "type" => "textarea", "attributes" => { "label" => "Last" } },
      ]
      values =
        FormTemplate::FieldValues.new(
          fields:,
          answers: {
            "first" => "one",
            "empty" => "",
            "unchecked" => false,
            "selections" => [],
            "null" => nil,
            "last" => "two",
          },
        )

      expect(described_class.render(values)).to eq("### First\none\n\n\n\n### Last\ntwo")
    end

    it "preserves unlabeled fields and trailing empty controls" do
      fields = [{ "id" => "unlabeled", "type" => "input" }, { "id" => "empty", "type" => "input" }]
      values =
        FormTemplate::FieldValues.new(fields:, answers: { "unlabeled" => "value", "empty" => "" })

      expect(described_class.render(values)).to eq("### undefined\nvalue\n\n")
    end

    it "renders empty forms and leaves answer types unchanged" do
      values = FormTemplate::FieldValues.new(fields: [], answers: {})

      expect(described_class.render(values)).to eq("")
      expect(values.answers).to eq({})
    end
  end
end
