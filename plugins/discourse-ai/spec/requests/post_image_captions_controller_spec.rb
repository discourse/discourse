# frozen_string_literal: true

describe DiscourseAi::PostImageCaptionsController do
  fab!(:admin)
  fab!(:post_author) { Fabricate(:user, trust_level: 4) }
  fab!(:translator, :user)
  fab!(:localizers, :group)
  fab!(:upload) do
    UploadCreator.new(
      file_from_fixtures(
        "100x100.jpg",
        "images",
        Rails.root.join("plugins/discourse-ai/spec/fixtures").to_s,
      ),
      "caption-image.jpg",
    ).create_for(post_author.id)
  end
  fab!(:post) do
    Fabricate(:post, user: post_author, raw: "![user supplied|200x200](#{upload.short_url})")
  end

  before do
    enable_current_plugin
    configure_valid_caption_agent
    SiteSetting.ai_post_image_captions_enabled = true
    SearchIndexer.enable
    post.update_column(:cooked, post.cook(post.raw, topic_id: post.topic_id))
    post.link_post_uploads
  end

  after { SearchIndexer.disable }

  def store_caption(
    description,
    target_post: post,
    target_upload: upload,
    locale: SiteSetting.default_locale
  )
    AiPostImageCaption.upsert_all(
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
      unique_by: DiscourseAi::PostImageCaptions::LOOKUP_INDEX,
    )
  end

  def configure_valid_caption_agent
    llm_model = assign_fake_provider_to(:ai_default_llm_model)
    llm_model.update!(vision_enabled: true)
    caption_agent =
      AiAgent.find_by(id: SiteSetting.ai_image_caption_agent.to_i) ||
        Fabricate(:ai_agent, id: SiteSetting.ai_image_caption_agent.to_i)
    caption_agent.update!(enabled: true, vision_enabled: true, default_llm_id: llm_model.id)
  end

  describe "#index" do
    before { sign_in(admin) }

    it "returns editable captions for current post images", :aggregate_failures do
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

      store_caption(description)
      store_caption("A stale description", target_upload: stale_upload)

      get "/discourse-ai/post-image-captions/#{post.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["captions"]).to contain_exactly(
        { "base62_sha1" => upload.base62_sha1, "description" => description },
      )
    end

    it "allows delegated translators to edit translated captions", :aggregate_failures do
      SiteSetting.content_localization_enabled = true
      SiteSetting.content_localization_supported_locales = "en|ja"
      SiteSetting.content_localization_allowed_groups = localizers.id.to_s
      localizers.add(translator)
      store_caption("翻訳前の説明", locale: "ja")
      sign_in(translator)

      get "/discourse-ai/post-image-captions/#{post.id}.json", params: { locale: "ja" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["captions"]).to contain_exactly(
        { "base62_sha1" => upload.base62_sha1, "description" => "翻訳前の説明" },
      )

      put "/discourse-ai/post-image-captions/#{post.id}/#{upload.base62_sha1}.json",
          params: {
            description: "翻訳後の説明",
            locale: "ja",
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "base62_sha1" => upload.base62_sha1,
        "description" => "翻訳後の説明",
      )
      expect(
        AiPostImageCaption.find_by(
          post_id: post.id,
          base62_sha1: upload.base62_sha1,
          locale: "ja",
        ).description,
      ).to eq("翻訳後の説明")

      store_caption("The original description")

      get "/discourse-ai/post-image-captions/#{post.id}.json"

      expect(response.status).to eq(403)
      expect(response.parsed_body["errors"]).to be_present

      put "/discourse-ai/post-image-captions/#{post.id}/#{upload.base62_sha1}.json",
          params: {
            description: "An unauthorized original description",
          }

      expect(response.status).to eq(403)
      expect(response.parsed_body["errors"]).to be_present
      expect(
        AiPostImageCaption.find_by(
          post_id: post.id,
          base62_sha1: upload.base62_sha1,
          locale: DiscourseAi::PostImageCaptions.original_locale(post),
        ).description,
      ).to eq("The original description")
    end

    it "rejects non-scalar original locales from delegated translators", :aggregate_failures do
      SiteSetting.content_localization_enabled = true
      SiteSetting.content_localization_supported_locales = "en|ja"
      SiteSetting.content_localization_allowed_groups = localizers.id.to_s
      localizers.add(translator)
      original_locale = DiscourseAi::PostImageCaptions.original_locale(post)
      store_caption("The original description", locale: original_locale)
      sign_in(translator)

      expect(translator.guardian.can_edit?(post)).to eq(false)
      expect(translator.guardian.can_localize_post?(post)).to eq(true)

      get "/discourse-ai/post-image-captions/#{post.id}.json", params: { locale: [original_locale] }

      expect(response.status).to eq(403)
      expect(response.parsed_body["errors"]).to be_present

      put "/discourse-ai/post-image-captions/#{post.id}/#{upload.base62_sha1}.json",
          params: {
            description: "An unauthorized original description",
            locale: [original_locale],
          }

      expect(response.status).to eq(403)
      expect(response.parsed_body["errors"]).to be_present
      expect(
        AiPostImageCaption.find_by(
          post_id: post.id,
          base62_sha1: upload.base62_sha1,
          locale: original_locale,
        ).description,
      ).to eq("The original description")
    end

    it "rejects translated captions for source editors without localization permission",
       :aggregate_failures do
      SiteSetting.content_localization_enabled = true
      SiteSetting.content_localization_supported_locales = "en|ja"
      SiteSetting.content_localization_allowed_groups = localizers.id.to_s
      SiteSetting.content_localization_allow_author_localization = false
      store_caption("The translated description", locale: "ja")
      sign_in(post_author)

      expect(post_author.guardian.can_edit?(post)).to eq(true)
      expect(post_author.guardian.can_localize_post?(post)).to eq(false)

      get "/discourse-ai/post-image-captions/#{post.id}.json", params: { locale: "ja" }

      expect(response.status).to eq(403)
      expect(response.parsed_body["errors"]).to be_present

      put "/discourse-ai/post-image-captions/#{post.id}/#{upload.base62_sha1}.json",
          params: {
            description: "An unauthorized translated description",
            locale: "ja",
          }

      expect(response.status).to eq(403)
      expect(response.parsed_body["errors"]).to be_present
      expect(
        AiPostImageCaption.find_by(
          post_id: post.id,
          base62_sha1: upload.base62_sha1,
          locale: "ja",
        ).description,
      ).to eq("The translated description")
    end
  end

  describe "#update" do
    before { sign_in(admin) }

    it "updates the caption and refreshes derived content", :aggregate_failures do
      store_caption("The old description")

      expect_enqueued_with(job: :process_post, args: { post_id: post.id }) do
        put "/discourse-ai/post-image-captions/#{post.id}/#{upload.base62_sha1}.json",
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
        AiPostImageCaption.find_by(post_id: post.id, base62_sha1: upload.base62_sha1).description,
      ).to eq("An edited 字 description")
      expect(post.post_search_data.raw_data).to include("An edited 字 description")

      Jobs::ProcessPost.new.execute(post_id: post.id)

      expect(post.reload.cooked).to include("An edited 字 description")
    end

    it "returns not found for images without an editable row" do
      put "/discourse-ai/post-image-captions/#{post.id}/#{upload.base62_sha1}.json",
          params: {
            description: "A new description",
          }

      expect(response.status).to eq(404)
    end

    it "validates caption length" do
      store_caption("The old description")

      put "/discourse-ai/post-image-captions/#{post.id}/#{upload.base62_sha1}.json",
          params: {
            description: "x" * (DiscourseAi::PostImageCaptions::MAX_CAPTION_LENGTH + 1),
          }

      expect(response.status).to eq(422)
    end
  end
end
