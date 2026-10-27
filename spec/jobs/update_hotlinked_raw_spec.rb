# frozen_string_literal: true

RSpec.describe Jobs::UpdateHotlinkedRaw do
  fab!(:upload)
  let(:url) { "https://x.co/i.png" }
  let(:template) do
    Fabricate(
      :form_template,
      template: [{ id: "image", type: "composer" }].as_json.to_yaml,
      output_template: "An invitation: {{ answers.image }}",
    )
  end
  let(:submission) do
    FormTemplate::Submission.from_template(template, answers: { "image" => "![game](#{url})" })
  end
  let(:post) do
    post = create_post(raw: submission.render, form_data: submission.to_h)
    post.post_hotlinked_media.create!(
      url: PostHotlinkedMedia.normalize_src(url),
      upload:,
      status: :downloaded,
    )
    post
  end

  it "keeps a submitted form editable after replacing hotlinked images in its answers" do
    described_class.new.execute(post_id: post.id)

    post.reload
    expect(post.raw).to include(upload.short_url)
    expect(post.raw).not_to include(url)
    expect(post.form_submission.answers["image"]).to include(upload.short_url)
  end

  it "falls back to markdown editing when the rewritten answers outgrow the size cap" do
    stub_const(FormTemplate::Submission, :MAX_BYTES, JSON.generate(post.form_data).bytesize + 1) do
      described_class.new.execute(post_id: post.id)
    end

    post.reload
    expect(post.raw).to include(upload.short_url)
    expect(post.form_data).to eq(submission.to_h)
    expect(post.form_submission).to be_nil
  end
end
