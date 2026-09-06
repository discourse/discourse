# frozen_string_literal: true

describe Jobs::GeneratePostImageCaptions do
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
  fab!(:post) { Fabricate(:post, raw: "![searchable image|200x200](#{upload.short_url})") }

  before do
    enable_current_plugin
    llm_model = assign_fake_provider_to(:ai_default_llm_model)
    llm_model.update!(vision_enabled: true)
    SiteSetting.ai_post_image_captions_enabled = true
    SiteSetting.ai_helper_enabled = true
    SearchIndexer.enable
    post.update_column(:cooked, post.cook(post.raw, topic_id: post.topic_id))
    post.link_post_uploads
  end

  after { SearchIndexer.disable }

  it "stores descriptions, reindexes, and queues a rebake", :aggregate_failures do
    description = "A cat beside 字 on a table"

    prompts = nil

    expect_enqueued_with(job: :process_post, args: { post_id: post.id }) do
      DiscourseAi::Completions::Llm.with_prepared_responses([description]) do |_, _, llm_prompts|
        prompts = llm_prompts

        described_class.new.execute(
          post_id: post.id,
          locale: SiteSetting.default_locale,
          base62_sha1s: [upload.base62_sha1],
        )
      end
    end

    image_caption = AiPostImageCaption.find_by(post_id: post.id, upload_id: upload.id)
    prompt = prompts.first

    expect(image_caption.description).to eq(description)
    expect(post.reload.post_search_data.raw_data).to include(description)
    expect(prompt.post_id).to eq(post.id)
    expect(prompt.topic_id).to eq(post.topic_id)
  end

  it "reuses a same-image same-locale description before calling the model", :aggregate_failures do
    existing_post = Fabricate(:post, raw: "![same image|200x200](#{upload.short_url})")
    existing_post.update_column(
      :cooked,
      existing_post.cook(existing_post.raw, topic_id: existing_post.topic_id),
    )
    existing_post.link_post_uploads

    AiPostImageCaption.create!(
      post_id: existing_post.id,
      upload_id: upload.id,
      base62_sha1: upload.base62_sha1,
      locale: SiteSetting.default_locale,
      description: "A reusable description",
      attempts: 1,
    )

    DiscourseAi::Completions::Llm.with_prepared_responses(["unused"]) do |canned_response|
      described_class.new.execute(
        post_id: post.id,
        locale: SiteSetting.default_locale,
        base62_sha1s: [upload.base62_sha1],
      )

      expect(canned_response.completions).to eq(0)
    end

    image_caption = AiPostImageCaption.find_by(post_id: post.id, upload_id: upload.id)

    expect(image_caption.description).to eq("A reusable description")
    expect(image_caption.attempts).to eq(0)
  end

  it "replaces retryable rows with reused descriptions", :aggregate_failures do
    existing_post = Fabricate(:post, raw: "![same image|200x200](#{upload.short_url})")
    existing_post.update_column(
      :cooked,
      existing_post.cook(existing_post.raw, topic_id: existing_post.topic_id),
    )
    existing_post.link_post_uploads

    AiPostImageCaption.create!(
      post_id: existing_post.id,
      upload_id: upload.id,
      base62_sha1: upload.base62_sha1,
      locale: SiteSetting.default_locale,
      description: "A reusable retry description",
      attempts: 1,
    )

    AiPostImageCaption.create!(
      post_id: post.id,
      upload_id: upload.id,
      base62_sha1: upload.base62_sha1,
      locale: SiteSetting.default_locale,
      description: nil,
      attempts: 1,
      last_attempted_at: 2.days.ago,
      last_error: "rate limited",
    )

    DiscourseAi::Completions::Llm.with_prepared_responses(["unused"]) do |canned_response|
      described_class.new.execute(
        post_id: post.id,
        locale: SiteSetting.default_locale,
        base62_sha1s: [upload.base62_sha1],
      )

      expect(canned_response.completions).to eq(0)
    end

    image_caption = AiPostImageCaption.find_by(post_id: post.id, upload_id: upload.id)

    expect(image_caption.description).to eq("A reusable retry description")
    expect(image_caption.attempts).to eq(0)
    expect(image_caption.last_attempted_at).to be_nil
    expect(image_caption.last_error).to be_nil
  end

  it "ignores images that are no longer in the post" do
    post.update_column(:cooked, "<p>No image</p>")

    DiscourseAi::Completions::Llm.with_prepared_responses(["unused"]) do
      described_class.new.execute(
        post_id: post.id,
        locale: SiteSetting.default_locale,
        base62_sha1s: [upload.base62_sha1],
      )
    end

    expect(AiPostImageCaption.exists?(post_id: post.id)).to eq(false)
  end

  it "records uncaptionable backfill candidates" do
    post.update_columns(cooked: "<p>No image</p>", image_upload_id: upload.id)

    described_class.new.execute(post_id: post.id, locale: SiteSetting.default_locale)

    image_caption = AiPostImageCaption.find_by(post_id: post.id, upload_id: upload.id)

    expect(image_caption.description).to be_nil
    expect(image_caption.attempts).to eq(1)
    expect(image_caption.last_error).to eq("no_post_image_nodes")
  end

  it "records blank responses without retrying immediately", :aggregate_failures do
    DiscourseAi::Completions::Llm.with_prepared_responses([""]) do
      described_class.new.execute(
        post_id: post.id,
        locale: SiteSetting.default_locale,
        base62_sha1s: [upload.base62_sha1],
      )
    end

    image_caption = AiPostImageCaption.find_by(post_id: post.id, upload_id: upload.id)

    expect(image_caption.description).to be_nil
    expect(image_caption.attempts).to eq(1)
    expect(image_caption.last_error).to eq("blank_response")

    DiscourseAi::Completions::Llm.with_prepared_responses(["second attempt"]) do
      described_class.new.execute(
        post_id: post.id,
        locale: SiteSetting.default_locale,
        base62_sha1s: [upload.base62_sha1],
      )
    end

    image_caption = AiPostImageCaption.find_by(post_id: post.id, upload_id: upload.id)

    expect(image_caption.description).to be_nil
    expect(image_caption.attempts).to eq(1)
  end

  it "updates retryable attempt rows", :aggregate_failures do
    DiscourseAi::Completions::Llm.with_prepared_responses([""]) do
      described_class.new.execute(
        post_id: post.id,
        locale: SiteSetting.default_locale,
        base62_sha1s: [upload.base62_sha1],
      )
    end

    AiPostImageCaption.where(
      post_id: post.id,
      locale: SiteSetting.default_locale,
      base62_sha1: upload.base62_sha1,
    ).update_all(last_attempted_at: 2.days.ago)

    DiscourseAi::Completions::Llm.with_prepared_responses(["second attempt"]) do
      described_class.new.execute(
        post_id: post.id,
        locale: SiteSetting.default_locale,
        base62_sha1s: [upload.base62_sha1],
      )
    end

    image_caption =
      AiPostImageCaption.find_by(
        post_id: post.id,
        locale: SiteSetting.default_locale,
        base62_sha1: upload.base62_sha1,
      )

    expect(image_caption.description).to eq("second attempt")
    expect(image_caption.attempts).to eq(2)
    expect(image_caption.last_error).to be_nil
  end

  it "limits generated descriptions per post", :aggregate_failures do
    second_upload =
      UploadCreator.new(
        file_from_fixtures(
          "An image of discobot in action.png",
          "images",
          Rails.root.join("plugins/discourse-ai/spec/fixtures").to_s,
        ),
        "second-image.png",
      ).create_for(Discourse.system_user.id)

    SiteSetting.ai_post_image_captions_per_post_limit = 1
    post.update!(
      raw:
        "![first image|200x200](#{upload.short_url})\n\n![second image|200x200](#{second_upload.short_url})",
    )
    post.update_column(:cooked, post.cook(post.raw, topic_id: post.topic_id))
    post.link_post_uploads

    DiscourseAi::Completions::Llm.with_prepared_responses(
      ["first generated description", "unused"],
    ) do |canned_response|
      described_class.new.execute(
        post_id: post.id,
        locale: SiteSetting.default_locale,
        base62_sha1s: [upload.base62_sha1, second_upload.base62_sha1],
      )

      expect(canned_response.completions).to eq(1)
    end

    expect(
      AiPostImageCaption.exists?(
        post_id: post.id,
        base62_sha1: upload.base62_sha1,
        description: "first generated description",
      ),
    ).to eq(true)
    expect(
      AiPostImageCaption.exists?(post_id: post.id, base62_sha1: second_upload.base62_sha1),
    ).to eq(false)
  end

  it "stores generated descriptions before a later image fails", :aggregate_failures do
    second_upload =
      UploadCreator.new(
        file_from_fixtures(
          "An image of discobot in action.png",
          "images",
          Rails.root.join("plugins/discourse-ai/spec/fixtures").to_s,
        ),
        "second-image.png",
      ).create_for(Discourse.system_user.id)

    post.update!(
      raw:
        "![first image|200x200](#{upload.short_url})\n\n![second image|200x200](#{second_upload.short_url})",
    )
    post.update_column(:cooked, post.cook(post.raw, topic_id: post.topic_id))
    post.link_post_uploads

    DiscourseAi::Completions::Llm.with_prepared_responses(
      ["A generated first image caption", StandardError.new("rate limited")],
    ) do
      described_class.new.execute(
        post_id: post.id,
        locale: SiteSetting.default_locale,
        base62_sha1s: [upload.base62_sha1, second_upload.base62_sha1],
      )
    end

    expect(AiPostImageCaption.find_by(post_id: post.id, upload_id: upload.id).description).to eq(
      "A generated first image caption",
    )
    expect(
      AiPostImageCaption.find_by(post_id: post.id, upload_id: second_upload.id).last_error,
    ).to eq("rate limited")
  end

  it "records non-owned secure uploads without sending them", :aggregate_failures do
    upload.update!(secure: true, access_control_post: Fabricate(:post))

    DiscourseAi::Completions::Llm.with_prepared_responses(["unused"]) do |canned_response|
      described_class.new.execute(
        post_id: post.id,
        locale: SiteSetting.default_locale,
        base62_sha1s: [upload.base62_sha1],
      )

      expect(canned_response.completions).to eq(0)
    end

    image_caption = AiPostImageCaption.find_by(post_id: post.id, upload_id: upload.id)

    expect(image_caption.description).to be_nil
    expect(image_caption.last_error).to eq("upload_not_captionable")
  end

  it "skips generation when credits are unavailable" do
    LlmCreditAllocation.stubs(:credits_available?).returns(false)

    DiscourseAi::Completions::Llm.with_prepared_responses(["unused"]) do
      described_class.new.execute(
        post_id: post.id,
        locale: SiteSetting.default_locale,
        base62_sha1s: [upload.base62_sha1],
      )
    end

    expect(AiPostImageCaption.exists?(post_id: post.id)).to eq(false)
  end

  it "keeps localized descriptions out of original search data", :aggregate_failures do
    description = "A localized 字 caption"

    DiscourseAi::Completions::Llm.with_prepared_responses([description]) do
      described_class.new.execute(
        post_id: post.id,
        locale: "ja",
        base62_sha1s: [upload.base62_sha1],
      )
    end

    expect(
      AiPostImageCaption.exists?(post_id: post.id, locale: "ja", description: description),
    ).to eq(true)
    expect(post.reload.post_search_data.raw_data).not_to include(description)
  end
end
