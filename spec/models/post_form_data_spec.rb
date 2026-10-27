# frozen_string_literal: true

RSpec.describe Post do
  describe "persisting form answers" do
    fab!(:form_template) do
      Fabricate(
        :form_template,
        template: [
          { id: "description", type: "input", validations: { required: true } },
        ].as_json.to_yaml,
        output_template: "A form whose required answer is omitted.",
      )
    end

    it "rejects incomplete snapshots on creation and updates even when raw matches" do
      complete =
        FormTemplate::Submission.from_template(
          form_template,
          answers: {
            "description" => "A complete answer",
          },
        )
      incomplete = complete.with_answers({ "description" => "" }, validate: false)
      unsaved = Fabricate.build(:post, raw: incomplete.normalized_raw, form_data: incomplete.to_h)

      expect(unsaved.save).to eq(false)
      expect(unsaved.errors[:form_data]).to be_present

      saved = Fabricate(:post, raw: complete.normalized_raw, form_data: complete.to_h)
      expect(saved.update(raw: incomplete.normalized_raw, form_data: incomplete.to_h)).to eq(false)
      expect(saved.errors[:form_data]).to be_present
      expect(saved.reload.form_data).to eq(complete.to_h)
    end
  end
end
