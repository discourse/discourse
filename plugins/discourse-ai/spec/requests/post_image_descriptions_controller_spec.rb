# frozen_string_literal: true

describe DiscourseAi::PostImageDescriptionsController do
  fab!(:admin)
  fab!(:upload) do
    UploadCreator.new(
      file_from_fixtures(
        "100x100.jpg",
        "images",
        Rails.root.join("plugins/discourse-ai/spec/fixtures").to_s,
      ),
      "caption-image.jpg",
    ).create_for(admin.id)
  end
  fab!(:post) do
    Fabricate(:post, user: admin, raw: "![user supplied|200x200](#{upload.short_url})")
  end

  before do
    enable_current_plugin
    SiteSetting.ai_post_image_descriptions_enabled = true
    SearchIndexer.enable
    post.update_column(:cooked, post.cook(post.raw, topic_id: post.topic_id))
    post.link_post_uploads
  end

  after { SearchIndexer.disable }

  def store_description(
    description,
    target_post: post,
    target_upload: upload,
    locale: SiteSetting.default_locale
  )
    AiPostImageDescription.upsert_all(
      [
        {
          post_id: target_post.id,
          upload_id: target_upload.id,
          base62_sha1: target_upload.base62_sha1,
          locale: locale,
          description: description,
          attempts: 0,
        },
      ],
      unique_by: DiscourseAi::PostImageDescriptions::LOOKUP_INDEX,
    )
  end

  describe "#index" do
    before { sign_in(admin) }

    it "returns editable descriptions for current post images", :aggregate_failures do
      description = "A generated 字 description"
      stale_upload =
        UploadCreator.new(
          file_from_fixtures(
            "1x1.jpg",
            "images",
            Rails.root.join("plugins/discourse-ai/spec/fixtures").to_s,
          ),
          "stale-caption-image.jpg",
        ).create_for(admin.id)

      store_description(description)
      store_description("A stale description", target_upload: stale_upload)

      get "/discourse-ai/post-image-descriptions/#{post.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["descriptions"]).to contain_exactly(
        { "base62_sha1" => upload.base62_sha1, "description" => description },
      )
    end

    it "requires permission to edit the post" do
      sign_in(Fabricate(:user))
      store_description("A generated description")

      get "/discourse-ai/post-image-descriptions/#{post.id}.json"

      expect(response.status).to eq(403)
    end
  end

  describe "#update" do
    before { sign_in(admin) }

    it "updates the description and refreshes derived content", :aggregate_failures do
      store_description("The old description")

      expect_enqueued_with(job: :process_post, args: { post_id: post.id }) do
        put "/discourse-ai/post-image-descriptions/#{post.id}/#{upload.base62_sha1}.json",
            params: {
              description: "An edited 字 description",
            }
      end

      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "base62_sha1" => upload.base62_sha1,
        "description" => "An edited 字 description",
      )
      expect(
        AiPostImageDescription.find_by(
          post_id: post.id,
          base62_sha1: upload.base62_sha1,
        ).description,
      ).to eq("An edited 字 description")
      expect(post.post_search_data.raw_data).to include("An edited 字 description")

      Jobs::ProcessPost.new.execute(post_id: post.id)

      expect(post.reload.cooked).to include("An edited 字 description")
    end

    it "returns not found for images without an editable row" do
      put "/discourse-ai/post-image-descriptions/#{post.id}/#{upload.base62_sha1}.json",
          params: {
            description: "A new description",
          }

      expect(response.status).to eq(404)
    end

    it "validates description length" do
      store_description("The old description")

      put "/discourse-ai/post-image-descriptions/#{post.id}/#{upload.base62_sha1}.json",
          params: {
            description: "x" * (DiscourseAi::PostImageDescriptions::MAX_DESCRIPTION_LENGTH + 1),
          }

      expect(response.status).to eq(422)
    end
  end
end
