# frozen_string_literal: true

RSpec.describe FormTemplate::OutputRenderer do
  let(:values) do
    FormTemplate::FieldValues.new(
      fields: [
        { "id" => "description", "type" => "composer", "attributes" => { "label" => "Details" } },
        { "id" => "games", "type" => "multi-select" },
        { "id" => "confirmed", "type" => "checkbox" },
      ],
      answers: {
        "description" => "**Hello**",
        "games" => %w[First Second],
        "confirmed" => true,
      },
    )
  end

  describe ".render" do
    it "renders typed answers using expressions, conditionals, and loops" do
      source =
        "{{ answers.description }}{% if answers.confirmed %}!{% endif %}{% for game in answers.games %}\n- {{ game }}{% endfor %}"
      expect(described_class.render(values, source)).to eq("**Hello**!\n- First\n- Second")
    end

    it "supports collection aliases and captures without interpreting answer content" do
      values.answers["description"] = "{{ answers.description | replace: 'x', 'y' }} (1..20000)"
      source = <<~LIQUID
        {% assign games = answers.games %}{% capture list %}{% for game in games %}- {{ game }}
        {% endfor %}{% endcapture %}{{ list }}{{ answers.description }}
      LIQUID
      expect(described_class.render(values, source)).to eq(
        "- First\n- Second\n#{values.answers["description"]}\n",
      )
    end

    it "uses the default output when no template is configured" do
      expect(described_class.render(values, nil)).to eq(
        FormTemplate::DefaultRenderer.render(values),
      )
    end

    it "rejects file-loading tags and unknown filters" do
      [
        "{% include 'secret' %}",
        "{% render 'secret' %}",
        "{{ answers.description | nonexistent_filter }}",
      ].each do |source|
        expect { described_class.render(values, source) }.to raise_error(Liquid::Error)
      end
    end

    it "rejects literal, dynamic, and indirectly assigned ranges before rendering" do
      # Large enough to exceed the work limit, but safe if the regression returns.
      values.answers["description"] = "20000"
      [
        "{% for index in (1..20000) %}x{% endfor %}",
        "{% for index in (1..answers.description) limit: 1 %}x{% endfor %}",
        "{% assign indices = (1..answers.description) %}{% for index in indices %}x{% endfor %}",
        "{% if false %}{% for index in (1..20000) %}x{% endfor %}{% endif %}",
      ].each do |source|
        expect { described_class.parse(source) }.to raise_error(Liquid::SyntaxError)
        expect { described_class.render(values, source) }.to raise_error(Liquid::Error)
      end
    end

    it "rejects filters in output, assignments, and inactive branches before rendering" do
      values.answers["description"] = "x" * 1000
      [
        "{{ answers.description | replace: 'x', answers.description }}",
        "{% assign expanded = answers.description | replace: 'x', answers.description %}{{ expanded }}",
        "{% if false %}{{ answers.games | join: answers.description }}{% endif %}",
      ].each do |source|
        expect { described_class.parse(source) }.to raise_error(Liquid::SyntaxError)
        expect { described_class.render(values, source) }.to raise_error(Liquid::Error)
      end
    end

    it "limits nested loop work and captured output" do
      values.answers["games"] = Array.new(200, "x")
      source =
        "{% for outer in answers.games %}{% for inner in answers.games %}x{% endfor %}{% endfor %}"
      expect { described_class.render(values, source) }.to raise_error(Liquid::Error)

      source =
        "{% capture text %}{% for game in answers.games %}abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz{% endfor %}{% endcapture %}{{ text }}"
      expect { described_class.render(values, source) }.to raise_error(Liquid::Error)
    end

    it "limits generated output and loop work" do
      SiteSetting.max_post_length = 100
      values.answers["games"] = ["x" * 500]
      source = "{% for game in answers.games %}{{ game }}{% endfor %}"
      expect { described_class.render(values, source) }.to raise_error(Liquid::Error)
    end
  end
end
