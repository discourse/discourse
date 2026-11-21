# frozen_string_literal: true

RSpec.describe FormDefinition do
  def definition(type, **properties)
    field = { id: "question", label: "Question", type:, required: true }.merge(properties)
    described_class.new({ title: "Survey", fields: [field] }.deep_stringify_keys)
  end

  it "applies the field type and required rules" do
    {
      "text" => ["hello", []],
      "textarea" => ["first\nsecond", "  "],
      "number" => [0, "many"],
      "date" => %w[2028-02-29 2027-02-29],
      "checkbox" => [true, false],
    }.each do |type, (valid, invalid)|
      form = definition(type)
      expect(form).to be_valid
      expect(form.invalid_answers("question" => valid)).to be_empty
      expect(form.invalid_answers("question" => invalid)).not_to be_empty
      expect(form.invalid_answers({})).not_to be_empty
    end
  end

  it "requires unique choices with labels and validates their stored IDs" do
    %w[dropdown radio].each do |type|
      choice = { id: "first", label: "Design" }
      form = definition(type, choices: [choice])
      expect(form).to be_valid
      expect(form.invalid_answers("question" => "first")).to be_empty
      expect(form.invalid_answers("question" => "Design")).not_to be_empty
      expect(definition(type, choices: [choice, choice])).not_to be_valid
      expect(definition(type, choices: [])).not_to be_valid
    end
  end

  it "limits placeholders to text, text area and number fields" do
    %w[text textarea number].each do |type|
      expect(definition(type, placeholder: "Answer")).to be_valid
    end
    expect(definition("date", placeholder: "Answer")).not_to be_valid
  end

  it "requires nonblank display text and excludes response attributes" do
    node = { "id" => "note", "type" => "display_text" }
    form = described_class.new({ "title" => "Survey", "fields" => [node] })
    node["content"] = " "
    expect(form).not_to be_valid
    node["content"] = "a" * 2001
    expect(form).not_to be_valid
    node["content"] = "Read this first."
    expect(form).to be_valid
    expect(form.invalid_answers({})).to be_empty
    node["required"] = true
    expect(form).not_to be_valid
  end

  it "accepts only distinct listed IDs for a checkbox group" do
    choices = [{ id: "first", label: "Design" }, { id: "second", label: "Testing" }]
    required = definition("checkboxes", choices:)
    expect(required).to be_valid
    expect(required.invalid_answers("question" => %w[first second])).to be_empty
    expect(required.invalid_answers("question" => ["second"])).to be_empty
    [[], "first", %w[first missing], %w[first first]].each do |answer|
      expect(required.invalid_answers("question" => answer)).not_to be_empty
    end
    optional = definition("checkboxes", choices:, required: false)
    expect(optional.invalid_answers("question" => [])).to be_empty
    expect(optional.invalid_answers({})).to be_empty
  end
end
