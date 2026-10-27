# frozen_string_literal: true

RSpec.describe Jobs::UpdateHotlinkedRaw do
  it "keeps a submitted form editable after replacing hotlinked images in its answers" do
    upload = Fabricate(:upload)
    url = "https://x.co/i.png"
    template =
      Fabricate(
        :form_template,
        template: [{ id: "image", type: "composer" }].as_json.to_yaml,
        output_template: "An invitation: {{ answers.image }}",
      )
    submission =
      FormTemplate::Submission.from_template(template, answers: { "image" => "![game](#{url})" })
    post = create_post(raw: submission.render, form_data: submission.to_h)
    post.post_hotlinked_media.create!(
      url: PostHotlinkedMedia.normalize_src(url),
      upload:,
      status: :downloaded,
    )

    described_class.new.execute(post_id: post.id)

    post.reload
    expect(post.raw).to include(upload.short_url)
    expect(post.raw).not_to include(url)
    expect(post.form_submission.answers["image"]).to include(upload.short_url)
  end
end
