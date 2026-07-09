# frozen_string_literal: true

describe DiscourseAi::PostImageDescriptions do
  fab!(:upload) { create_image_upload("100x100.jpg", "caption-image.jpg") }
  fab!(:post) { Fabricate(:post, raw: "![user supplied|200x200](#{upload.short_url})") }

  before do
    enable_current_plugin
    llm_model = assign_fake_provider_to(:ai_default_llm_model)
    llm_model.update!(vision_enabled: true)
    AiAgent.find_by(id: SiteSetting.ai_helper_image_caption_agent).update!(
      enabled: true,
      vision_enabled: true,
    )
    SiteSetting.ai_post_image_descriptions_enabled = true
    SiteSetting.ai_helper_enabled = true
    post.update_column(:cooked, post.cook(post.raw, topic_id: post.topic_id))
    post.link_post_uploads
  end

  def create_image_upload(filename, original_filename)
    UploadCreator.new(discourse_ai_image_fixture(filename), original_filename).create_for(
      Discourse.system_user.id,
    )
  end

  def discourse_ai_image_fixture(filename)
    file_from_fixtures(
      filename,
      "images",
      Rails.root.join("plugins/discourse-ai/spec/fixtures").to_s,
    )
  end

  def store_description(description, locale: SiteSetting.default_locale, target_upload: upload)
    AiPostImageDescription.upsert_all(
      [
        {
          post_id: post.id,
          upload_id: target_upload.id,
          base62_sha1: target_upload.base62_sha1,
          locale: locale,
          description: description,
          attempts: 0,
        },
      ],
      unique_by: described_class::LOOKUP_INDEX,
    )
  end

  it "supports ActiveRecord updates with a primary key" do
    image_description =
      AiPostImageDescription.create!(
        post_id: post.id,
        upload_id: upload.id,
        base62_sha1: upload.base62_sha1,
        locale: SiteSetting.default_locale,
        description: "An initial description",
      )

    image_description.update!(description: "An updated description")

    expect(image_description.reload.description).to eq("An updated description")
  end

  it "adds image description metadata without visible text", :aggregate_failures do
    description = "A lighthouse beside 字 on a sign"
    store_description(description)

    processor = CookedPostProcessor.new(post)
    processor.post_process
    doc = Nokogiri::HTML5.fragment(processor.html)
    image = doc.at_css("img[data-base62-sha1='#{upload.base62_sha1}']")
    lightbox = doc.at_css("a.lightbox")

    expect(post.raw).not_to include(description)
    expect(image["alt"]).to eq("user supplied")
    expect(lightbox["title"]).to eq("user supplied")
    expect(doc.at_css(".meta .filename").text).to eq("user supplied")
    expect(image["data-ai-description"]).to eq(description)
    expect(image["aria-description"]).to include(description)
    expect(doc.at_css(".ai-image-description")).to be_blank
    expect(
      ExcerptParser.to_plain_text(ExcerptParser.get_excerpt(processor.html, 200)),
    ).not_to include(description)
  end

  it "strips image description metadata from email HTML", :aggregate_failures do
    description = "A generated email-only 字 description"
    store_description(description)

    processor = CookedPostProcessor.new(post)
    processor.post_process
    email_html = PrettyText.format_for_email(processor.html, post)
    email_doc = Nokogiri::HTML5.fragment(email_html)

    expect(email_html).not_to include(description)
    expect(email_doc.at_css("[data-ai-description]")).to be_blank
    expect(email_doc.at_css("[aria-description]")).to be_blank
  end

  it "enqueues generation for post images only" do
    attachment = create_image_upload("An image of discobot in action.png", "attachment.png")

    post.update!(
      raw:
        "![visible image|200x200](#{upload.short_url})\n\n" \
          "[attached image|attachment](#{attachment.short_url})",
    )
    post.update_column(:cooked, post.cook(post.raw, topic_id: post.topic_id))
    post.link_post_uploads

    expect_enqueued_with(
      job: :generate_post_image_descriptions,
      args: {
        post_id: post.id,
        locale: SiteSetting.default_locale,
        base62_sha1s: [upload.base62_sha1],
      },
    ) do
      processor = CookedPostProcessor.new(post)
      processor.post_process
    end
  end

  it "does not run when post image descriptions are disabled" do
    SiteSetting.ai_post_image_descriptions_enabled = false

    expect_not_enqueued_with(job: :generate_post_image_descriptions) do
      described_class.process_cooked(Nokogiri::HTML5.fragment(post.cooked), post, locale: "en")
    end
  end

  it "does not enqueue generation when the caption agent is disabled" do
    AiAgent.find_by(id: SiteSetting.ai_helper_image_caption_agent).update!(enabled: false)

    expect(described_class.generation_enabled?).to eq(false)
    expect_not_enqueued_with(job: :generate_post_image_descriptions) do
      described_class.process_cooked(
        Nokogiri::HTML5.fragment(post.cooked),
        post,
        locale: SiteSetting.default_locale,
      )
    end
  end

  it "does not enqueue generation while cooking old posts" do
    post.update_columns(created_at: 2.days.ago, updated_at: 2.days.ago)

    expect_not_enqueued_with(job: :generate_post_image_descriptions) do
      processor = CookedPostProcessor.new(post)
      processor.post_process
    end
  end

  it "enqueues generation for recently edited old posts" do
    post.update_columns(created_at: 2.days.ago, updated_at: Time.zone.now)

    expect_enqueued_with(
      job: :generate_post_image_descriptions,
      args: {
        post_id: post.id,
        locale: SiteSetting.default_locale,
        base62_sha1s: [upload.base62_sha1],
      },
    ) do
      processor = CookedPostProcessor.new(post)
      processor.post_process
    end
  end

  it "preserves non-AI image aria descriptions when disabled", :aggregate_failures do
    SiteSetting.ai_post_image_descriptions_enabled = false
    doc =
      Nokogiri::HTML5.fragment(
        "<a class='lightbox' aria-description='custom lightbox'>" \
          "<img src='https://example.com/image.png' aria-description='custom image'>" \
          "</a>",
      )

    described_class.process_cooked(doc, post, locale: SiteSetting.default_locale)

    expect(doc.at_css("img")["aria-description"]).to eq("custom image")
    expect(doc.at_css("a.lightbox")["aria-description"]).to eq("custom lightbox")
  end

  it "skips personal messages and whispers" do
    private_topic = Fabricate(:private_message_topic, user: post.user)
    pm_post = Fabricate(:post, topic: private_topic, raw: post.raw)
    pm_post.update_column(:cooked, post.cooked)
    pm_post.link_post_uploads

    whisper = Fabricate(:post, raw: post.raw, post_type: Post.types[:whisper])
    whisper.update_column(:cooked, post.cooked)
    whisper.link_post_uploads

    expect_not_enqueued_with(job: :generate_post_image_descriptions) do
      described_class.process_cooked(
        Nokogiri::HTML5.fragment(pm_post.cooked),
        pm_post,
        locale: "en",
      )
      described_class.process_cooked(
        Nokogiri::HTML5.fragment(whisper.cooked),
        whisper,
        locale: "en",
      )
    end
  end

  it "ignores image nodes without post upload references" do
    unrelated_upload = create_image_upload("An image of discobot in action.png", "unrelated.png")

    expect_not_enqueued_with(job: :generate_post_image_descriptions) do
      described_class.process_cooked(
        Nokogiri::HTML5.fragment(
          "<img src='https://example.com/image.png' data-base62-sha1='#{unrelated_upload.base62_sha1}'>" \
            "<img src='https://example.com/other.png' data-base62-sha1='@bad'>",
        ),
        post,
        locale: SiteSetting.default_locale,
      )
    end
  end

  it "adds current image descriptions to search text" do
    default_description = "A searchable 字 description"
    japanese_description = "A Japanese 字 description"
    store_description(default_description)
    store_description(japanese_description, locale: "ja")

    indexed_text = described_class.append_to_search_text("body", post.id, post.cooked)
    text_without_image = described_class.append_to_search_text("body", post.id, "<p>No image</p>")

    expect(indexed_text).to include(default_description)
    expect(indexed_text).not_to include(japanese_description)
    expect(text_without_image).to eq("body")
  end

  it "does not delete other locale descriptions during localized cooking" do
    store_description("A default locale description")
    store_description("A Japanese description", locale: "ja")
    other_upload = create_image_upload("An image of discobot in action.png", "other-image.png")
    post.update!(raw: "![other image|200x200](#{other_upload.short_url})")
    post.update_column(:cooked, post.cook(post.raw, topic_id: post.topic_id))
    post.link_post_uploads

    described_class.process_cooked(Nokogiri::HTML5.fragment(post.cooked), post, locale: "ja")

    expect(
      AiPostImageDescription.exists?(
        post_id: post.id,
        locale: SiteSetting.default_locale,
        base62_sha1: upload.base62_sha1,
      ),
    ).to eq(true)
    expect(
      AiPostImageDescription.exists?(
        post_id: post.id,
        locale: "ja",
        base62_sha1: upload.base62_sha1,
      ),
    ).to eq(false)
  end

  it "adds descriptions while storing localized cooked", :aggregate_failures do
    description = "日本語の画像説明"
    store_description(description, locale: "ja")
    localization =
      Fabricate(:post_localization, post: post, locale: "ja", raw: post.raw, cooked: post.cooked)

    Jobs::ProcessLocalizedCooked.new.execute(post_localization_id: localization.id)

    doc = Nokogiri::HTML5.fragment(localization.reload.cooked)
    image = doc.at_css("img[data-base62-sha1='#{upload.base62_sha1}']")

    expect(image["data-ai-description"]).to eq(description)
    expect(image["aria-description"]).to include(description)
    expect(doc.at_css(".ai-image-description")).to be_blank
  end

  it "falls back to original descriptions while localized generation is pending",
     :aggregate_failures do
    description = "A default locale fallback description"
    store_description(description)
    localization =
      Fabricate(:post_localization, post: post, locale: "ja", raw: post.raw, cooked: post.cooked)

    expect_enqueued_with(
      job: :generate_post_image_descriptions,
      args: {
        post_id: post.id,
        locale: "ja",
        base62_sha1s: [upload.base62_sha1],
      },
    ) { Jobs::ProcessLocalizedCooked.new.execute(post_localization_id: localization.id) }

    doc = Nokogiri::HTML5.fragment(localization.reload.cooked)
    image = doc.at_css("img[data-base62-sha1='#{upload.base62_sha1}']")

    expect(image["data-ai-description"]).to eq(description)
    expect(image["aria-description"]).to include(description)
    expect(AiPostImageDescription.exists?(post_id: post.id, locale: "ja")).to eq(false)
  end

  it "deletes descriptions after all post images are removed" do
    store_description("A stored description")

    described_class.process_cooked(Nokogiri::HTML5.fragment("<p>No image</p>"), post, locale: "en")

    expect(AiPostImageDescription.exists?(post_id: post.id, base62_sha1: upload.base62_sha1)).to eq(
      false,
    )
  end

  it "keeps stored descriptions when the feature is disabled" do
    store_description("A stored description")
    SiteSetting.ai_post_image_descriptions_enabled = false

    described_class.process_cooked(Nokogiri::HTML5.fragment("<p>No image</p>"), post, locale: "en")

    expect(AiPostImageDescription.exists?(post_id: post.id, base62_sha1: upload.base62_sha1)).to eq(
      true,
    )
  end

  it "deletes descriptions only when the post is permanently destroyed", :aggregate_failures do
    store_description("A stored description")
    admin = Fabricate(:admin)

    PostDestroyer.new(admin, post).destroy

    expect(AiPostImageDescription.exists?(post_id: post.id)).to eq(true)

    PostDestroyer.new(admin, post.reload, force_destroy: true).destroy

    expect(AiPostImageDescription.exists?(post_id: post.id)).to eq(false)
  end
end
