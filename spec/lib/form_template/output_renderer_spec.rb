# frozen_string_literal: true

RSpec.describe FormTemplate::OutputRenderer do
  let(:values) do
    FormTemplate::FieldValues.new(
      fields: [
        { "id" => "description", "type" => "composer", "attributes" => { "label" => "Details" } },
        { "id" => "games", "type" => "multi-select" },
        { "id" => "confirmed", "type" => "checkbox" },
        { "id" => "seats", "type" => "input", "validations" => { "type" => "number" } },
      ],
      answers: {
        "description" => "**Hello**",
        "games" => %w[First Second],
        "confirmed" => true,
        "seats" => "",
      },
    )
  end

  describe ".render" do
    it "renders typed answers using expressions, conditionals, and loops" do
      source =
        "{{ answers.description }}{% if answers.confirmed %}!{% endif %}{% for game in answers.games %}\n- {{ game }}{% endfor %}"
      expect(described_class.render(values, source)).to eq("**Hello**!\n- First\n- Second")
    end

    it "supports filters for collections and empty answers" do
      source = "{{ answers.games | join: ', ' }} / {{ answers.seats | default: 'any' }}"
      expect(described_class.render(values, source)).to eq("First, Second / any")
    end

    it "does not interpret answer content" do
      values.answers["description"] = "{{ answers.games | join: '' }} {% if true %}x{% endif %}"
      expect(described_class.render(values, "{{ answers.description }}")).to eq(
        values.answers["description"],
      )
    end

    it "uses the default output when no template is configured" do
      expect(described_class.render(values, nil)).to eq(
        FormTemplate::DefaultRenderer.render(values),
      )
    end

    it "limits generated output to a multiple of the post length" do
      SiteSetting.max_post_length = 100
      values.answers["games"] = ["x" * 500]
      source = "{% for game in answers.games %}{{ game }}{% endfor %}"
      expect { described_class.render(values, source) }.to raise_error(Liquid::MemoryError)
    end

    it "limits rendering work" do
      values.answers["games"] = Array.new(500, "x")
      source =
        "{% for outer in answers.games %}{% for inner in answers.games %}{% assign seen = inner %}{% endfor %}{% endfor %}"
      expect { described_class.render(values, source) }.to raise_error(Liquid::MemoryError)
    end
  end
end
