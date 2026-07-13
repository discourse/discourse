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
    SiteSetting.ai_translation_category_scope = "all"
    SiteSetting.ai_translation_categories = ""
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
    post_2 = Fabricate(:post, locale: nil, topic: post.topic)
    post_3 = Fabricate(:post, locale: nil, topic: post.topic)

    post.update!(updated_at: 3.days.ago)
    post_2.update!(updated_at: 2.days.ago)
    post_3.update!(updated_at: 4.days.ago)

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

  context "when relocalize quota is exhausted" do
    before do
      # max out quota
      DiscourseAi::Translation::PostLocalizer::MAX_QUOTA_PER_DAY.times do
        DiscourseAi::Translation::PostLocalizer.has_relocalize_quota?(post, "")
      end
    end

    it "skips locale detection for posts that have exceeded quota" do
      DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).never

      job.execute({})
    end
  end

  it "logs a summary after running" do
    DiscourseAi::Translation::PostLocaleDetector.stubs(:detect_locale)
    DiscourseAi::Translation::VerboseLogger.expects(:log).with(includes("Detected 1 post locales"))

    job.execute({})
  end

  describe "with selected categories" do
    fab!(:included_category, :category)
    fab!(:excluded_category, :category)
    fab!(:included_topic) { Fabricate(:topic, category: included_category) }
    fab!(:excluded_topic) { Fabricate(:topic, category: excluded_category) }
    fab!(:included_post) { Fabricate(:post, topic: included_topic, locale: nil) }
    fab!(:excluded_post) { Fabricate(:post, topic: excluded_topic, locale: nil) }

    fab!(:group)
    fab!(:group_pm_topic) { Fabricate(:private_message_topic, allowed_groups: [group]) }
    fab!(:group_pm_post) { Fabricate(:post, topic: group_pm_topic, locale: nil) }

    fab!(:pm_topic, :private_message_topic)
    fab!(:pm_post) { Fabricate(:post, topic: pm_topic, locale: nil) }

    before do
      SiteSetting.ai_translation_category_scope = "include"
      SiteSetting.ai_translation_categories = included_category.id.to_s
      SiteSetting.ai_translation_personal_messages = "none"
    end

    it "only processes posts from selected categories" do
      DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(included_post).once
      DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(excluded_post).never
      DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(group_pm_post).never
      DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(pm_post).never

      job.execute({})
    end

    it "processes included posts and group PMs when pm_translation_scope is group" do
      SiteSetting.ai_translation_personal_messages = "group"

      DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(included_post).once
      DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(excluded_post).never
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
