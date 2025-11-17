# frozen_string_literal: true

describe Jobs::TagsLocaleDetectionBackfill do
  subject(:job) { described_class.new }

  fab!(:tag) { Fabricate(:tag, locale: nil) }

  before do
    assign_fake_provider_to(:ai_default_llm_model)
    enable_current_plugin
    SiteSetting.ai_translation_enabled = true
    SiteSetting.ai_translation_backfill_hourly_rate = 100
    SiteSetting.ai_translation_backfill_max_age_days = 30
    SiteSetting.content_localization_supported_locales = "en"
  end

  it "does nothing when AI is disabled" do
    SiteSetting.discourse_ai_enabled = false
    DiscourseAi::Translation::TagLocaleDetector.expects(:detect_locale).never

    job.execute({})
  end

  it "does nothing when content translation is disabled" do
    SiteSetting.ai_translation_enabled = false
    DiscourseAi::Translation::TagLocaleDetector.expects(:detect_locale).never

    job.execute({})
  end

  it "does nothing when backfill rate is 0" do
    SiteSetting.ai_translation_backfill_hourly_rate = 0
    DiscourseAi::Translation::TagLocaleDetector.expects(:detect_locale).never

    job.execute({})
  end

  it "does nothing when there are no tags to detect" do
    Tag.update_all(locale: "en")
    DiscourseAi::Translation::TagLocaleDetector.expects(:detect_locale).never

    job.execute({})
  end

  it "detects locale for tags with nil locale" do
    DiscourseAi::Translation::TagLocaleDetector.expects(:detect_locale).with(tag).once

    job.execute({})
  end

  it "handles detection errors gracefully" do
    DiscourseAi::Translation::TagLocaleDetector
      .expects(:detect_locale)
      .with(tag)
      .raises(StandardError.new("error"))
      .once

    expect { job.execute({}) }.not_to raise_error
  end

  it "logs a summary after running" do
    DiscourseAi::Translation::TagLocaleDetector.stubs(:detect_locale)
    DiscourseAi::Translation::VerboseLogger.expects(:log).with(includes("Detected 1 tag locales"))

    job.execute({})
  end

  describe "with public content limitation" do
    fab!(:tag_group)
    fab!(:restricted_group, :group)

    before do
      SiteSetting.ai_translation_backfill_limit_to_public_content = true
      # set the existing tag's locale so it won't be processed
      tag.update!(locale: "en")
    end

    it "processes tags not in any tag group" do
      standalone_tag = Fabricate(:tag, locale: nil)
      DiscourseAi::Translation::TagLocaleDetector.expects(:detect_locale).with(standalone_tag).once

      job.execute({})
    end

    it "processes tags in tag groups visible to everyone" do
      public_tag = Fabricate(:tag, locale: nil)
      tag_group.tags << public_tag
      TagGroupPermission.create!(
        tag_group: tag_group,
        group_id: Group::AUTO_GROUPS[:everyone],
        permission_type: TagGroupPermission.permission_types[:full],
      )

      DiscourseAi::Translation::TagLocaleDetector.expects(:detect_locale).with(public_tag).once

      job.execute({})
    end

    it "skips tags in tag groups not visible to everyone" do
      restricted_tag = Fabricate(:tag, locale: nil)
      tag_group.tags << restricted_tag
      TagGroupPermission.where(tag_group: tag_group).destroy_all
      TagGroupPermission.create!(
        tag_group: tag_group,
        group_id: restricted_group.id,
        permission_type: TagGroupPermission.permission_types[:full],
      )

      DiscourseAi::Translation::TagLocaleDetector.expects(:detect_locale).with(restricted_tag).never

      job.execute({})
    end
  end

  it "limits processing to the backfill rate" do
    SiteSetting.ai_translation_backfill_hourly_rate = 1
    Fabricate(:tag, locale: nil)

    DiscourseAi::Translation::TagLocaleDetector.expects(:detect_locale).once

    job.execute({})
  end
end
