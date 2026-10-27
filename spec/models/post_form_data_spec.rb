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

  describe "linking uploads from saved answers" do
    it "retains omitted videos and thumbnails without publishing them as topic images" do
      SiteSetting.video_thumbnails_enabled = true
      video = Fabricate(:upload, extension: "mp4")
      thumbnail = Fabricate(:upload, original_filename: "#{video.sha1}.png")
      template =
        Fabricate(
          :form_template,
          template: [{ id: "video", type: "composer" }].as_json.to_yaml,
          output_template: "A form with an omitted video answer.",
        )
      submission =
        FormTemplate::Submission.from_template(
          template,
          answers: {
            "video" => "<video controls><source src=\"#{Discourse.base_url}#{video.url}\"></video>",
          },
        )
      saved = Fabricate(:post, raw: submission.normalized_raw, form_data: submission.to_h)

      CookedPostProcessor.new(saved).post_process

      expect(saved.upload_references.pluck(:upload_id)).to contain_exactly(video.id, thumbnail.id)
      expect(saved.topic.reload.image_upload_id).to be_nil
      expect(saved.topic.topic_thumbnails).to be_empty

      data = submission.to_h
      data["definition"]["output_template"] = "{{ answers.video }}"
      visible = FormTemplate::Submission.new(data)
      saved.update!(raw: visible.normalized_raw, form_data: visible.to_h)
      saved.link_post_uploads

      expect(saved.topic.reload.image_upload_id).to eq(thumbnail.id)
      expect(saved.upload_references.pluck(:upload_id)).to contain_exactly(video.id, thumbnail.id)
    end
  end
end
