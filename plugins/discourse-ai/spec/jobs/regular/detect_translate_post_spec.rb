# frozen_string_literal: true

describe Jobs::DetectTranslatePost do
  subject(:job) { described_class.new }

  fab!(:post)

  let(:locales) { %w[en ja] }

  before do
    assign_fake_provider_to(:ai_default_llm_model)
    # fake provider (Completions::Endpoints::Fake) returns translated text that includes this svg
    stub_request(:get, "https://meta.discourse.org/images/discourse-logo.svg").to_return(
      status: 200,
      body: "",
    )

    enable_current_plugin
    SiteSetting.ai_translation_enabled = true
    SiteSetting.content_localization_supported_locales = locales.join("|")
    SiteSetting.ai_translation_category_scope = "all"
    SiteSetting.ai_translation_categories = ""
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

  it "skips translation when credits are unavailable" do
    DiscourseAi::Translation.expects(:credits_available_for_post_detection?).returns(false)
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

  it "skips bot posts by default" do
    post.update!(user: Discourse.system_user)
    DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).never
    DiscourseAi::Translation::PostLocalizer.expects(:localize).never

    job.execute({ post_id: post.id })
  end

  it "translates bot posts when force is true" do
    post.update!(user: Discourse.system_user)
    DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).once

    job.execute({ post_id: post.id, force: true })
  end

  it "translates bot posts when ai_translation_include_bot_content is true" do
    SiteSetting.ai_translation_include_bot_content = true
    post.update!(user: Discourse.system_user)
    DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).once

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

    it "translates if force is true" do
      post.update(locale: "en")
      Fabricate(:post_localization, post:, locale: "ja")

      DiscourseAi::Translation::PostLocalizer.expects(:localize).with(post, "ja").once

      job.execute({ post_id: post.id, force: true })
    end
  end

  it "handles translation errors gracefully" do
    post.update(locale: "en")
    DiscourseAi::Translation::PostLocalizer.expects(:localize).raises(
      StandardError.new("API error"),
    )

    expect { job.execute({ post_id: post.id }) }.not_to raise_error
  end

  describe "with category scope and PM scope" do
    fab!(:included_category, :category)
    fab!(:excluded_category, :category)
    fab!(:included_topic) { Fabricate(:topic, category: included_category) }
    fab!(:excluded_topic) { Fabricate(:topic, category: excluded_category) }
    fab!(:included_post) { Fabricate(:post, topic: included_topic) }
    fab!(:excluded_post) { Fabricate(:post, topic: excluded_topic) }

    fab!(:personal_pm_topic, :private_message_topic)
    fab!(:personal_pm_post) { Fabricate(:post, topic: personal_pm_topic) }

    fab!(:group_pm_topic) do
      Fabricate(:group_private_message_topic, recipient_group: Fabricate(:group))
    end
    fab!(:group_pm_post) { Fabricate(:post, topic: group_pm_topic) }

    before do
      SiteSetting.ai_translation_category_scope = "exclude"
      SiteSetting.ai_translation_categories = excluded_category.id.to_s
    end

    it "skips posts outside the category scope" do
      DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(excluded_post).never
      job.execute({ post_id: excluded_post.id })
    end

    it "processes posts in included categories" do
      DiscourseAi::Translation::PostLocaleDetector.expects(:detect_locale).with(included_post).once
      job.execute({ post_id: included_post.id })
    end

    it "processes posts from selected subcategories" do
      subcategory = Fabricate(:category, parent_category: included_category)
      subcategory_post = Fabricate(:post, topic: Fabricate(:topic, category: subcategory))
      SiteSetting.ai_translation_category_scope = "include"
      SiteSetting.ai_translation_categories = included_category.id.to_s

      DiscourseAi::Translation::PostLocaleDetector
        .expects(:detect_locale)
        .with(subcategory_post)
        .once

      job.execute({ post_id: subcategory_post.id })
    end

    context "when pm_translation_scope is none" do
      before { SiteSetting.ai_translation_personal_messages = "none" }

      it "skips all PMs" do
        DiscourseAi::Translation::PostLocaleDetector
          .expects(:detect_locale)
          .with(personal_pm_post)
          .never
        job.execute({ post_id: personal_pm_post.id })

        DiscourseAi::Translation::PostLocaleDetector
          .expects(:detect_locale)
          .with(group_pm_post)
          .never
        job.execute({ post_id: group_pm_post.id })
      end
    end

    context "when pm_translation_scope is group" do
      before { SiteSetting.ai_translation_personal_messages = "group" }

      it "processes group PMs but skips personal PMs" do
        DiscourseAi::Translation::PostLocaleDetector
          .expects(:detect_locale)
          .with(group_pm_post)
          .once
        job.execute({ post_id: group_pm_post.id })

        DiscourseAi::Translation::PostLocaleDetector
          .expects(:detect_locale)
          .with(personal_pm_post)
          .never
        job.execute({ post_id: personal_pm_post.id })
      end
    end

    context "when pm_translation_scope is all" do
      before { SiteSetting.ai_translation_personal_messages = "all" }

      it "processes all PMs" do
        DiscourseAi::Translation::PostLocaleDetector
          .expects(:detect_locale)
          .with(group_pm_post)
          .once
        job.execute({ post_id: group_pm_post.id })

        DiscourseAi::Translation::PostLocaleDetector
          .expects(:detect_locale)
          .with(personal_pm_post)
          .once
        job.execute({ post_id: personal_pm_post.id })
      end
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
