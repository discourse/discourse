# frozen_string_literal: true

describe Jobs::PostsLocaleDetectionBackfill do
  subject(:job) { described_class.new }

  fab!(:post) { Fabricate(:post, locale: nil) }

  before do
    assign_fake_provider_to(:ai_default_llm_model)
    enable_current_plugin
    SiteSetting.ai_translation_enabled = true
    SiteSetting.ai_translation_backfill_hourly_rate = 100
    SiteSetting.content_localization_supported_locales = "en"
  end

  it "does nothing when translator is disabled" do
    SiteSetting.discourse_ai_enabled = false
    DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).never

    job.execute({})
  end

  it "does nothing when content translation is disabled" do
    SiteSetting.ai_translation_enabled = false
    DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).never

    job.execute({})
  end

  it "does nothing when there are no posts to detect" do
    Post.update_all(locale: "en")
    DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).never

    job.execute({})
  end

  it "detects locale for posts with nil locale" do
    DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(post).once
    job.execute({})
  end

  it "detects most recently updated posts first" do
    post_2 = Fabricate(:post, locale: nil)
    post_3 = Fabricate(:post, locale: nil)

    post.update!(updated_at: 3.days.ago)
    post_2.update!(updated_at: 2.day.ago)
    post_3.update!(updated_at: 4.day.ago)

    SiteSetting.ai_translation_backfill_hourly_rate = 12

    DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(post_2).once
    DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(post).never
    DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(post_3).never

    job.execute({})
  end

  it "skips bot posts" do
    post.update!(user: Discourse.system_user)
    DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(post).never

    job.execute({})
  end

  it "handles detection errors gracefully" do
    DiscourseAi::Translation::PostLocaleDetector
      .expects(:detect_locale)
      .with(post)
      .raises(StandardError.new("jiboomz"))
      .once

    expect { job.execute({}) }.not_to raise_error
  end

  it "logs a summary after running" do
    DiscourseAi::Translation::PostLocaleDetector.stubs(:detect_locale)
    DiscourseAi::Translation::VerboseLogger.expects(:log).with(includes("Detected 1 post locales"))

    job.execute({})
  end

  describe "with public content limitation" do
    fab!(:private_category) { Fabricate(:private_category, group: Group[:staff]) }
    fab!(:private_cat_topic) { Fabricate(:topic, category: private_category) }
    fab!(:private_cat_post) { Fabricate(:post, topic: private_cat_topic, locale: nil) }

    fab!(:group)
    fab!(:group_pm_topic) { Fabricate(:private_message_topic, allowed_groups: [group]) }
    fab!(:group_pm_post) { Fabricate(:post, topic: group_pm_topic, locale: nil) }

    fab!(:pm_topic) { Fabricate(:private_message_topic) }
    fab!(:pm_post) { Fabricate(:post, topic: pm_topic, locale: nil) }

    before { SiteSetting.ai_translation_backfill_limit_to_public_content = true }

    it "only processes posts from public categories" do
      DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(post).once
      DiscourseAi::Translation::PostLocaleDetector
        .expects(:detect_locale)
        .with(private_cat_post)
        .never
      DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(group_pm_post).never
      DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(pm_post).never

      job.execute({})
    end

    it "processes all public content and group PMs and private categories when setting is disabled" do
      SiteSetting.ai_translation_backfill_limit_to_public_content = false

      DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(post).once
      DiscourseAi::Translation::PostLocaleDetector
        .expects(:detect_locale)
        .with(private_cat_post)
        .once
      DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(group_pm_post).once
      DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(pm_post).never

      job.execute({})
    end
  end

  describe "with max age limit" do
    fab!(:old_post) { Fabricate(:post, locale: nil, created_at: 10.days.ago) }
    fab!(:new_post) { Fabricate(:post, locale: nil, created_at: 2.days.ago) }

    before { SiteSetting.ai_translation_backfill_max_age_days = 5 }

    it "only processes posts within the age limit" do
      # other posts
      DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).at_least_once

      DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(new_post).once
      DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(old_post).never

      job.execute({})
    end

    it "processes all posts when setting is large" do
      SiteSetting.ai_translation_backfill_max_age_days = 100

      # other posts
      DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).at_least_once

      DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(new_post).once
      DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(old_post).once

      job.execute({})
    end
  end
end
