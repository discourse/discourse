# frozen_string_literal: true

describe Jobs::DetectTranslatePost do
  subject(:job) { described_class.new }

  fab!(:post)

  let(:locales) { %w[en ja] }

  before do
    assign_fake_provider_to(:ai_default_llm_model)
    enable_current_plugin
    SiteSetting.ai_translation_enabled = true
    SiteSetting.content_localization_supported_locales = locales.join("|")
  end

  it "does nothing when translator is disabled" do
    SiteSetting.discourse_ai_enabled = false
    DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).never
    DiscourseAi::Translation::PostLocalizer.expects(:localize).never

    job.execute({ post_id: post.id })
  end

  it "does nothing when content translation is disabled" do
    SiteSetting.ai_translation_enabled = false
    DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).never
    DiscourseAi::Translation::PostLocalizer.expects(:localize).never

    job.execute({ post_id: post.id })
  end

  it "detects locale" do
    allow(DiscourseAi::Translation::PostLocaleDetector).to receive(:detect_locale).with(
      post,
    ).and_return("zh_CN")

    job.execute({ post_id: post.id })
  end

  it "skips locale detection when post has a locale" do
    post.update!(locale: "en")
    DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(post).never

    job.execute({ post_id: post.id })
  end

  it "skips bot posts" do
    post.update!(user: Discourse.system_user)
    DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).never
    DiscourseAi::Translation::PostLocalizer.expects(:localize).never

    job.execute({ post_id: post.id })
  end

  it "skips locale detection when no target languages are configured" do
    SiteSetting.content_localization_supported_locales = ""
    DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).never
    DiscourseAi::Translation::PostLocalizer.expects(:localize).never

    job.execute({ post_id: post.id })
  end

  it "skips translating to the post's language" do
    post.update(locale: "en")
    DiscourseAi::Translation::PostLocalizer.expects(:localize).with(post, "en").never
    DiscourseAi::Translation::PostLocalizer.expects(:localize).with(post, "ja").once

    job.execute({ post_id: post.id })
  end

  context "when translation exists and retranslation quota hit" do
    before do
      DiscourseAi::Translation::PostLocalizer
        .expects(:has_relocalize_quota?)
        .with(post, "ja")
        .returns(false)
    end

    it "skips translating if the post is already localized" do
      post.update(locale: "en")
      Fabricate(:post_localization, post:, locale: "ja")

      DiscourseAi::Translation::PostLocalizer.expects(:localize).never

      job.execute({ post_id: post.id })
    end

    it "does not translate to language of similar variant" do
      post.update(locale: "en_GB")
      Fabricate(:post_localization, post: post, locale: "ja_JP")

      DiscourseAi::Translation::PostLocalizer.expects(:localize).never

      job.execute({ post_id: post.id })
    end
  end

  it "handles translation errors gracefully" do
    post.update(locale: "en")
    DiscourseAi::Translation::PostLocalizer.expects(:localize).raises(
      StandardError.new("API error"),
    )

    expect { job.execute({ post_id: post.id }) }.not_to raise_error
  end

  describe "with public content and PM limitations" do
    fab!(:private_category) { Fabricate(:private_category, group: Group[:staff]) }
    fab!(:private_topic) { Fabricate(:topic, category: private_category) }
    fab!(:private_post) { Fabricate(:post, topic: private_topic) }

    fab!(:personal_pm_topic) { Fabricate(:private_message_topic) }
    fab!(:personal_pm_post) { Fabricate(:post, topic: personal_pm_topic) }

    fab!(:group_pm_topic) do
      Fabricate(:group_private_message_topic, recipient_group: Fabricate(:group))
    end
    fab!(:group_pm_post) { Fabricate(:post, topic: group_pm_topic) }

    context "when ai_translation_backfill_limit_to_public_content is true" do
      before { SiteSetting.ai_translation_backfill_limit_to_public_content = true }

      it "skips posts from restricted categories and PMs" do
        DiscourseAi::Translation::PostLocaleDetector
          .expects(:detect_locale)
          .with(private_post)
          .never
        DiscourseAi::Translation::PostLocalizer
          .expects(:localize)
          .with(private_post, any_parameters)
          .never
        job.execute({ post_id: private_post.id })

        DiscourseAi::Translation::PostLocaleDetector
          .expects(:detect_locale)
          .with(personal_pm_post)
          .never
        DiscourseAi::Translation::PostLocalizer
          .expects(:localize)
          .with(personal_pm_post, any_parameters)
          .never
        job.execute({ post_id: personal_pm_post.id })

        DiscourseAi::Translation::PostLocaleDetector
          .expects(:detect_locale)
          .with(group_pm_post)
          .never
        DiscourseAi::Translation::PostLocalizer
          .expects(:localize)
          .with(group_pm_post, any_parameters)
          .never
        job.execute({ post_id: group_pm_post.id })
      end
    end

    context "when ai_translation_backfill_limit_to_public_content is false" do
      before { SiteSetting.ai_translation_backfill_limit_to_public_content = false }

      it "processes posts from private categories and group PMs but skips personal PMs" do
        DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(private_post).once
        job.execute({ post_id: private_post.id })

        DiscourseAi::Translation::PostLocaleDetector
          .expects(:detect_locale)
          .with(group_pm_post)
          .once
        job.execute({ post_id: group_pm_post.id })

        DiscourseAi::Translation::PostLocaleDetector
          .expects(:detect_locale)
          .with(personal_pm_post)
          .never
        DiscourseAi::Translation::PostLocalizer
          .expects(:localize)
          .with(personal_pm_post, any_parameters)
          .never
        job.execute({ post_id: personal_pm_post.id })
      end

      describe "force arg" do
        it "processes private content when force is true" do
          DiscourseAi::Translation::PostLocaleDetector
            .expects(:detect_locale)
            .with(group_pm_post)
            .once

          job.execute({ post_id: group_pm_post.id, force: true })
        end

        it "processes PM content when force is true" do
          DiscourseAi::Translation::PostLocaleDetector
            .expects(:detect_locale)
            .with(personal_pm_post)
            .once

          job.execute({ post_id: personal_pm_post.id, force: true })
        end
      end
    end
  end
end
