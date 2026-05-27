# frozen_string_literal: true

describe Jobs::LocalizePosts do
  subject(:job) { described_class.new }

  fab!(:post)

  before do
    assign_fake_provider_to(:ai_default_llm_model)
    enable_current_plugin
    SiteSetting.ai_translation_enabled = true
    SiteSetting.content_localization_supported_locales = "en|ja|de"
    SiteSetting.ai_translation_backfill_hourly_rate = 100
    SiteSetting.ai_translation_backfill_max_age_days = 100
  end

  it "does nothing when translator is disabled" do
    SiteSetting.discourse_ai_enabled = false
    DiscourseAi::Translation::PostLocalizer.expects(:localize).never

    job.execute({ pairs: [[post.id, "ja"]] })
  end

  it "does nothing when ai_translation_enabled is disabled" do
    SiteSetting.ai_translation_enabled = false
    DiscourseAi::Translation::PostLocalizer.expects(:localize).never

    job.execute({ pairs: [[post.id, "ja"]] })
  end

  it "does nothing when no target languages are configured" do
    SiteSetting.content_localization_supported_locales = ""
    DiscourseAi::Translation::PostLocalizer.expects(:localize).never

    job.execute({ pairs: [[post.id, "ja"]] })
  end

  it "does nothing when ai_translation_backfill_hourly_rate is 0" do
    SiteSetting.ai_translation_backfill_hourly_rate = 0
    DiscourseAi::Translation::PostLocalizer.expects(:localize).never

    job.execute({ pairs: [[post.id, "ja"]] })
  end

  it "skips translation when credits are unavailable" do
    DiscourseAi::Translation.expects(:credits_available_for_post_localization?).returns(false)
    DiscourseAi::Translation::PostLocalizer.expects(:localize).never

    job.execute({ pairs: [[post.id, "ja"]] })
  end

  it "skips pairs where post is not found" do
    DiscourseAi::Translation::PostLocalizer.expects(:localize).never

    job.execute({ pairs: [[-1, "ja"]] })
  end

  it "translates each pair it receives" do
    DiscourseAi::Translation::PostLocalizer
      .expects(:localize)
      .with(post, "en", has_entries(llm_model: anything))
      .once
    DiscourseAi::Translation::PostLocalizer
      .expects(:localize)
      .with(post, "ja", has_entries(llm_model: anything))
      .once

    job.execute({ pairs: [[post.id, "en"], [post.id, "ja"]] })
  end

  it "handles translation errors gracefully" do
    DiscourseAi::Translation::PostLocalizer
      .expects(:localize)
      .with(post, "en", has_entries(llm_model: anything))
      .raises(StandardError.new("API error"))
    DiscourseAi::Translation::PostLocalizer
      .expects(:localize)
      .with(post, "ja", has_entries(llm_model: anything))
      .once

    expect { job.execute({ pairs: [[post.id, "en"], [post.id, "ja"]] }) }.not_to raise_error
  end

  it "logs a summary after translation" do
    DiscourseAi::Translation::PostLocalizer.stubs(:localize)
    DiscourseAi::Translation::VerboseLogger.expects(:log).with(
      includes("Translated 2/2 post localizations"),
    )

    job.execute({ pairs: [[post.id, "en"], [post.id, "ja"]] })
  end

  context "when relocalize quota is exhausted" do
    it "skips localization for posts that have exceeded quota for a specific locale" do
      DiscourseAi::Translation::PostLocalizer::MAX_QUOTA_PER_DAY.times do
        DiscourseAi::Translation::PostLocalizer.has_relocalize_quota?(post, "en")
      end

      DiscourseAi::Translation::PostLocalizer
        .expects(:localize)
        .with(post, "en", has_entries(llm_model: anything))
        .never
      DiscourseAi::Translation::PostLocalizer
        .expects(:localize)
        .with(post, "ja", has_entries(llm_model: anything))
        .once

      job.execute({ pairs: [[post.id, "en"], [post.id, "ja"]] })
    end
  end

  describe "LlmModel caching" do
    it "caches the LlmModel and reuses it for all posts in a batch" do
      post_1 = Fabricate(:post, topic: post.topic)
      post_2 = Fabricate(:post, topic: post.topic)

      find_by_call_count = 0
      LlmModel
        .stubs(:find_by)
        .with do
          find_by_call_count += 1
          true
        end
        .returns(LlmModel.last)

      DiscourseAi::Translation::PostLocalizer.stubs(:localize)

      job.execute({ pairs: [[post_1.id, "ja"], [post_2.id, "ja"]] })

      # 1. Once in credits_available_for_post_localization? check
      # 2. Once in the job's find_llm_model_for_agent for caching
      expect(find_by_call_count).to eq(2)
    end
  end
end
