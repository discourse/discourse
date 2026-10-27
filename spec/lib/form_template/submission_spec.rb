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
    it "rejects oversized submissions" do
      expect do
        described_class.from_template(
          form_template,
          answers: answers.merge("description" => "x" * described_class::MAX_BYTES),
          validate: false,
        )
      end.to raise_error(described_class::TooLarge)
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

  describe "#rewrite_answers" do
    it "rewrites textual answers without touching the definition or typed values" do
      rewritten =
        submission.rewrite_answers { |text| text.gsub("Second", "Third").gsub("first", "last") }

      expect(rewritten.answers).to eq(
        answers.merge(
          "description" => "First paragraph\n\n**Third paragraph**",
          "options" => %w[last second],
        ),
      )
      expect(rewritten.to_h["definition"]).to eq(submission.to_h["definition"])
      expect(rewritten.render).to eq("## Invitation\nFirst paragraph\n\n**Third paragraph**")
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

      data = saved.editor_data(guardian: Fabricate(:user).guardian)
      field = YAML.safe_load(data[:template]).first
      expect(field["choices"]).to eq([])
      expect(field.dig("attributes", "tag_choices")).to eq({})
      expect(saved.to_h.dig("definition", "fields", 0, "choices")).to eq(
        [{ "id" => tag.id, "name" => tag.name }],
      )
    end
  end
end
