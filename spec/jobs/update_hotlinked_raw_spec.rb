# frozen_string_literal: true

RSpec.describe Jobs::UpdateHotlinkedRaw do
  it "preserves downloaded images and editing when localization exceeds the submission size limit" do
    upload = Fabricate(:upload)
    url = "https://x.co/i.png"
    template =
      Fabricate(
        :form_template,
        template: [
          { id: "image", type: "composer" },
          { id: "confirmed", type: "checkbox" },
          { id: "note", type: "composer" },
        ].as_json.to_yaml,
        output_template:
          "An invitation: {% if answers.image %}{{ answers.image | strip }}{% endif %}",
      )
    submission =
      FormTemplate::Submission.from_template(
        template,
        answers: {
          "image" => "![game](#{url})",
          "confirmed" => false,
          "note" => "",
        },
      )
    data = submission.to_h
    data["answers"]["note"] = "x" *
      (FormTemplate::Submission::MAX_BYTES - JSON.generate(data).bytesize)
    submission = FormTemplate::Submission.new(data)
    post = create_post(raw: submission.render, form_data: submission.to_h)
    post.post_hotlinked_media.create!(
      url: PostHotlinkedMedia.normalize_src(url),
      upload:,
      status: :downloaded,
    )

    described_class.new.execute(post_id: post.id)

    post.reload
    expect(JSON.generate(post.form_data).bytesize).to be > FormTemplate::Submission::MAX_BYTES
    expect(post.raw).to include(upload.short_url)
    expect(post.form_submission.render).to eq(post.raw)
    changed =
      post.form_submission.with_answers(post.form_submission.answers.merge("confirmed" => true))
    PostRevisor.new(post).revise!(post.user, { raw: changed.render, form_data: changed.to_h })
    expect(post.reload.raw).to include(upload.short_url)
    expect(post.raw).not_to include(url)
    expect(post.form_submission.answers["confirmed"]).to eq(true)
  end
end
