# frozen_string_literal: true

RSpec.describe Jobs::UpdateHotlinkedRaw do
  it "preserves downloaded images when another form answer is edited" do
    upload = Fabricate(:upload)
    url = "https://example.com/game.png"
    template =
      Fabricate(
        :form_template,
        template: [
          { id: "image", type: "composer" },
          { id: "confirmed", type: "checkbox" },
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
        },
      )
    post = create_post(raw: submission.render, form_data: submission.to_h)
    post.post_hotlinked_media.create!(
      url: PostHotlinkedMedia.normalize_src(url),
      upload:,
      status: :downloaded,
    )

    described_class.new.execute(post_id: post.id)

    post.reload
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
