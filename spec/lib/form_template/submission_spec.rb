# frozen_string_literal: true

RSpec.describe FormTemplate::Submission do
  fab!(:form_template) do
    Fabricate(
      :form_template,
      template: [
        { id: "description", type: "composer", attributes: { label: "Details" } },
        { id: "confirmed", type: "checkbox" },
        { id: "seats", type: "input", validations: { type: "number" } },
        { id: "options", type: "multi-select", choices: %w[first second] },
      ].as_json.to_yaml,
      output_template: "## Invitation\n{{ answers.description }}",
    )
  end
  let(:answers) do
    {
      "description" => "First paragraph\n\n**Second paragraph**",
      "confirmed" => false,
      "seats" => "0",
      "options" => %w[first second],
    }
  end
  let(:submission) { described_class.from_template(form_template, answers:) }

  describe ".from_template" do
    it "rejects oversized new submissions" do
      expect do
        described_class.from_template(
          form_template,
          answers: answers.merge("description" => "x" * described_class::MAX_BYTES),
          validate: false,
        )
      end.to raise_error(ArgumentError)
    end

    it "retains numeric spelling and isolates the snapshot from caller mutations" do
      form_template.update!(output_template: nil)
      snapshot = described_class.from_template(form_template, answers: { "seats" => "1e2" })
      exported = snapshot.to_h
      exported["answers"]["seats"] = "200"
      expect(snapshot.render).to eq("### seats\n1e2")
      expect(snapshot.answers).to eq("seats" => "1e2")
    end
  end

  describe ".new" do
    it "rejects incompatible envelopes and invalid answers" do
      data = submission.to_h
      [
        data.merge("format_version" => 2),
        data.merge("extra" => true),
        data.merge("definition" => { "fields" => "invalid", "output_template" => nil }),
        data.merge("answers" => { "confirmed" => "false" }),
      ].each { |invalid| expect { described_class.new(invalid) }.to raise_error(ArgumentError) }
    end

    it "bounds snapshot nesting" do
      nested = submission.to_h
      nested["answers"]["description"] = 25.times.reduce("x") { |value, _index| [value] }
      expect { described_class.new(nested) }.to raise_error(ArgumentError)
    end
  end

  describe "#rewrite_text" do
    it "allows system rewrites to grow saved snapshots while limiting subsequent edits" do
      original = submission.to_h
      original["answers"]["description"] = "@old "
      original["answers"]["description"] += "x" *
        (described_class::MAX_BYTES - JSON.generate(original).bytesize)
      saved = described_class.new(original)

      rewritten = saved.rewrite_text { |text| text.gsub("@old", "@longer_username") }
      reopened = described_class.new(rewritten.to_h)
      expect(reopened.render).to include("@longer_username")
      expect(JSON.generate(reopened.to_h).bytesize).to be > described_class::MAX_BYTES
      expect(reopened.with_answers(reopened.answers).to_h).to eq(rewritten.to_h)
      expect do
        reopened.with_answers(
          reopened.answers.merge("description" => reopened.answers["description"] + "x"),
        )
      end.to raise_error(ArgumentError)
      shortened = reopened.with_answers(reopened.answers.merge("description" => "Shorter answer"))
      expect do shortened.with_answers(reopened.answers) end.to raise_error(ArgumentError)
    end

    it "evaluates conditions and filters using rewritten answers" do
      data = submission.to_h
      data["answers"]["description"] = "@old"
      data["definition"][
        "output_template"
      ] = "{% if answers.description == '@old' %}Original{% else %}{{ answers.description | upcase }}{% endif %}"

      rewritten = described_class.new(data).rewrite_text { |text| text.gsub("@old", "@new") }

      expect(rewritten.answers["description"]).to eq("@new")
      expect(rewritten.render).to eq("@NEW")
      expect(rewritten.to_h["definition"]).to eq(data["definition"])
    end

    it "rewrites labels, choices and literal output while preserving field references and typed values" do
      data = submission.to_h
      data["definition"]["fields"] << { "id" => "@old", "type" => "input" }
      data["definition"]["fields"].find { |field| field["id"] == "options" }["choices"] = ["@old"]
      data["answers"].merge!(
        "@old" => "A reply",
        "description" => "Ask @old",
        "options" => ["@old"],
      )
      data["definition"]["output_template"] = '@old: {{ answers["description"] }}'
      rewritten = described_class.new(data).rewrite_text { |text| text.gsub("@old", "@new") }

      expect(rewritten.render).to eq("@new: Ask @new")
      expect(rewritten.answers).to eq(
        data["answers"].merge("description" => "Ask @new", "options" => ["@new"]),
      )
      fields = rewritten.to_h.dig("definition", "fields")
      expect(fields.last).to eq(
        "id" => "@old",
        "type" => "input",
        "attributes" => {
          "label" => "@new",
        },
      )
      expect(fields.find { |field| field["id"] == "options" }["choices"]).to eq(["@new"])
    end
  end

  describe "#editor_data" do
    it "filters saved tag choices using the current editor's permissions without changing the snapshot" do
      tag = Fabricate(:tag, description: "A restricted choice")
      group = Fabricate(:tag_group, tags: [tag])
      form_template.update!(
        template: [{ id: "game", type: "tag-chooser", tag_group: group.name }].as_json.to_yaml,
      )
      form_template.process!(Fabricate(:admin).guardian)
      saved = described_class.from_template(form_template, answers: {})
      group.update!(permissions: { staff: :full })

      data = saved.editor_data(raw: saved.render, guardian: Fabricate(:user).guardian)
      field = YAML.safe_load(data[:template]).first
      expect(field["choices"]).to eq([])
      expect(field.dig("attributes", "tag_choices")).to eq({})
      expect(saved.to_h.dig("definition", "fields", 0, "choices")).to eq(
        [{ "id" => tag.id, "name" => tag.name }],
      )
    end
  end

  describe "#state_token" do
    it "ignores object key order while covering answers and raw" do
      raw = submission.render
      reordered = described_class.new(submission.to_h.to_a.reverse.to_h)
      reordered_data = reordered.to_h
      reordered_data["answers"] = answers.to_a.reverse.to_h
      reordered = described_class.new(reordered_data)
      expect(reordered.state_token(raw:)).to eq(submission.state_token(raw:))
      changed = submission.with_answers(answers.merge("confirmed" => true))
      expect(changed.render).to eq(raw)
      expect(changed.state_token(raw:)).not_to eq(submission.state_token(raw:))
      expect(submission.state_token(raw: "Other body")).not_to eq(submission.state_token(raw:))
    end
  end
end
