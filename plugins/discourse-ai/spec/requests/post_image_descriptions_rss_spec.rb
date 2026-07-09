# frozen_string_literal: true

describe "AI post image descriptions in RSS" do
  fab!(:upload) do
    UploadCreator.new(
      file_from_fixtures(
        "100x100.jpg",
        "images",
        Rails.root.join("plugins/discourse-ai/spec/fixtures").to_s,
      ),
      "caption-image.jpg",
    ).create_for(Discourse.system_user.id)
  end

  fab!(:post) { Fabricate(:post, raw: "![user supplied|200x200](#{upload.short_url})") }

  before do
    enable_current_plugin
    SiteSetting.ai_post_image_descriptions_enabled = true
    post.update_column(:cooked, post.cook(post.raw, topic_id: post.topic_id))
    post.link_post_uploads
  end

  it "omits generated descriptions from topic feeds", :aggregate_failures do
    description = "A generated RSS-only 字 description"
    AiPostImageDescription.upsert_all(
      [
        {
          post_id: post.id,
          upload_id: upload.id,
          base62_sha1: upload.base62_sha1,
          locale: SiteSetting.default_locale,
          description: description,
          attempts: 0,
        },
      ],
      unique_by: DiscourseAi::PostImageDescriptions::LOOKUP_INDEX,
    )

    processor = CookedPostProcessor.new(post)
    processor.post_process
    post.update_column(:cooked, processor.html)

    get "/t/#{post.topic.slug}/#{post.topic.id}.rss"

    expect(response.status).to eq(200)
    expect(response.body).not_to include(description)
    expect(response.body).not_to include("data-ai-description")
    expect(response.body).not_to include("aria-description")
  end
end
