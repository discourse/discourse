# frozen_string_literal: true

describe Jobs::PostImageDescriptionsBackfill do
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
  fab!(:post) { Fabricate(:post, raw: "![backfill image|200x200](#{upload.short_url})") }

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
    post.update_column(:image_upload_id, upload.id)
  end

  def store_description(target_upload)
    AiPostImageDescription.upsert_all(
      [
        {
          post_id: post.id,
          upload_id: target_upload.id,
          base62_sha1: target_upload.base62_sha1,
          locale: SiteSetting.default_locale,
          description: "A stored description",
          attempts: 0,
        },
      ],
      unique_by: DiscourseAi::PostImageDescriptions::LOOKUP_INDEX,
    )
  end

  def store_attempt(created_at:, target_post: nil, last_attempted_at: nil)
    target_post ||= Fabricate(:post)

    AiPostImageDescription.create!(
      post_id: target_post.id,
      upload_id: upload.id,
      base62_sha1: upload.base62_sha1,
      locale: SiteSetting.default_locale,
      attempts: 1,
      last_attempted_at: last_attempted_at,
      created_at: created_at,
      updated_at: created_at,
    )
  end

  it "does nothing when backfill is disabled" do
    SiteSetting.ai_post_image_descriptions_backfill_hourly_rate = 0

    expect_not_enqueued_with(job: :generate_post_image_descriptions) do
      described_class.new.execute({})
    end
  end

  it "does nothing when post image descriptions are disabled" do
    SiteSetting.ai_post_image_descriptions_enabled = false
    SiteSetting.ai_post_image_descriptions_backfill_hourly_rate = 4

    expect_not_enqueued_with(job: :generate_post_image_descriptions) do
      described_class.new.execute({})
    end
  end

  it "enqueues posts without existing descriptions" do
    SiteSetting.ai_post_image_descriptions_backfill_hourly_rate = 4

    expect_enqueued_with(
      job: :generate_post_image_descriptions,
      args: {
        post_id: post.id,
        locale: SiteSetting.default_locale,
      },
    ) { described_class.new.execute({}) }
  end

  it "enqueues one post when a low hourly backfill budget is unused" do
    SiteSetting.ai_post_image_descriptions_backfill_hourly_rate = 1

    expect_enqueued_with(
      job: :generate_post_image_descriptions,
      args: {
        post_id: post.id,
        locale: SiteSetting.default_locale,
      },
    ) { described_class.new.execute({}) }
  end

  it "enqueues existing localized posts when localization is enabled" do
    SiteSetting.content_localization_enabled = true
    SiteSetting.ai_post_image_descriptions_backfill_hourly_rate = 8
    Fabricate(:post_localization, post: post, locale: "ja", raw: post.raw, cooked: post.cooked)

    described_class.new.execute({})

    jobs =
      Jobs::GeneratePostImageDescriptions
        .jobs
        .last(2)
        .map { |job| job["args"].first.slice("post_id", "locale") }

    expect(jobs).to contain_exactly(
      { "post_id" => post.id, "locale" => SiteSetting.default_locale },
      { "post_id" => post.id, "locale" => "ja" },
    )
  end

  it "does not enqueue posts older than the backfill max age" do
    SiteSetting.ai_post_image_descriptions_backfill_hourly_rate = 4
    SiteSetting.ai_post_image_descriptions_backfill_max_age_days = 30
    post.update_column(:created_at, 31.days.ago)

    expect_not_enqueued_with(job: :generate_post_image_descriptions) do
      described_class.new.execute({})
    end
  end

  it "respects the hourly backfill budget" do
    SiteSetting.ai_post_image_descriptions_backfill_hourly_rate = 1
    store_attempt(created_at: 10.minutes.ago)

    expect_not_enqueued_with(job: :generate_post_image_descriptions) do
      described_class.new.execute({})
    end
  end

  it "counts recent retry attempts against the backfill budget" do
    SiteSetting.ai_post_image_descriptions_backfill_hourly_rate = 1
    store_attempt(created_at: 2.days.ago, last_attempted_at: 10.minutes.ago)

    expect_not_enqueued_with(job: :generate_post_image_descriptions) do
      described_class.new.execute({})
    end
  end

  it "does not repeatedly enqueue described posts with image attachments" do
    other_upload =
      UploadCreator.new(
        file_from_fixtures(
          "An image of discobot in action.png",
          "images",
          Rails.root.join("plugins/discourse-ai/spec/fixtures").to_s,
        ),
        "other-image.png",
      ).create_for(Discourse.system_user.id)

    post.update!(
      raw:
        "![first image|200x200](#{upload.short_url})\n\n" \
          "[attached image|attachment](#{other_upload.short_url})",
    )
    post.update_column(:cooked, post.cook(post.raw, topic_id: post.topic_id))
    post.link_post_uploads
    store_description(upload)

    SiteSetting.ai_post_image_descriptions_backfill_hourly_rate = 4

    expect_not_enqueued_with(job: :generate_post_image_descriptions) do
      described_class.new.execute({})
    end
  end

  it "does not enqueue posts with an original locale description" do
    store_description(upload)
    SiteSetting.ai_post_image_descriptions_backfill_hourly_rate = 4

    expect_not_enqueued_with(job: :generate_post_image_descriptions) do
      described_class.new.execute({})
    end
  end

  it "does not immediately re-enqueue recently attempted posts" do
    AiPostImageDescription.upsert_all(
      [
        {
          post_id: post.id,
          upload_id: upload.id,
          base62_sha1: upload.base62_sha1,
          locale: SiteSetting.default_locale,
          description: nil,
          attempts: 1,
          last_attempted_at: Time.zone.now,
          last_error: "blank_response",
        },
      ],
      unique_by: DiscourseAi::PostImageDescriptions::LOOKUP_INDEX,
    )

    SiteSetting.ai_post_image_descriptions_backfill_hourly_rate = 4

    expect_not_enqueued_with(job: :generate_post_image_descriptions) do
      described_class.new.execute({})
    end
  end

  it "re-enqueues posts with retryable image attempts" do
    other_upload =
      UploadCreator.new(
        file_from_fixtures(
          "An image of discobot in action.png",
          "images",
          Rails.root.join("plugins/discourse-ai/spec/fixtures").to_s,
        ),
        "other-image.png",
      ).create_for(Discourse.system_user.id)

    post.update!(
      raw:
        "![first image|200x200](#{upload.short_url})\n\n![second image|200x200](#{other_upload.short_url})",
    )
    post.update_column(:cooked, post.cook(post.raw, topic_id: post.topic_id))
    post.link_post_uploads
    store_description(upload)

    AiPostImageDescription.upsert_all(
      [
        {
          post_id: post.id,
          upload_id: other_upload.id,
          base62_sha1: other_upload.base62_sha1,
          locale: SiteSetting.default_locale,
          description: nil,
          attempts: 1,
          last_attempted_at: 2.days.ago,
          last_error: "rate limited",
        },
      ],
      unique_by: DiscourseAi::PostImageDescriptions::LOOKUP_INDEX,
    )

    SiteSetting.ai_post_image_descriptions_backfill_hourly_rate = 4

    expect_enqueued_with(
      job: :generate_post_image_descriptions,
      args: {
        post_id: post.id,
        locale: SiteSetting.default_locale,
      },
    ) { described_class.new.execute({}) }
  end

  it "does not enqueue when credits are unavailable" do
    SiteSetting.ai_post_image_descriptions_backfill_hourly_rate = 4
    LlmCreditAllocation.stubs(:credits_available?).returns(false)

    expect_not_enqueued_with(job: :generate_post_image_descriptions) do
      described_class.new.execute({})
    end
  end

  it "uses post image ids for backfill candidates" do
    SiteSetting.ai_post_image_descriptions_backfill_hourly_rate = 4
    post.update_column(:cooked, "<p>No upload marker</p>")

    expect_enqueued_with(
      job: :generate_post_image_descriptions,
      args: {
        post_id: post.id,
        locale: SiteSetting.default_locale,
      },
    ) { described_class.new.execute({}) }
  end

  it "does not enqueue attachment-only posts" do
    SiteSetting.ai_post_image_descriptions_backfill_hourly_rate = 4
    post.update_column(:image_upload_id, nil)

    expect_not_enqueued_with(job: :generate_post_image_descriptions) do
      described_class.new.execute({})
    end
  end
end
