# frozen_string_literal: true

describe Jobs::DetectTranslateTopic do
  subject(:job) { described_class.new }

  fab!(:topic)

  let(:locales) { %w[en ja] }

  before do
    assign_fake_provider_to(:ai_default_llm_model)
    enable_current_plugin
    SiteSetting.ai_translation_enabled = true
    SiteSetting.content_localization_supported_locales = locales.join("|")
    SiteSetting.ai_translation_category_scope = "all"
    SiteSetting.ai_translation_categories = ""
  end

  it "does nothing when translator is disabled" do
    SiteSetting.discourse_ai_enabled = false
    DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).never
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

    job.execute({ topic_id: topic.id })
  end

  it "does nothing when content translation is disabled" do
    SiteSetting.ai_translation_enabled = false
    DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).never
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

    job.execute({ topic_id: topic.id })
  end

  it "skips translation when credits are unavailable" do
    DiscourseAi::Translation.expects(:credits_available_for_topic_detection?).returns(false)
    DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).never
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

    job.execute({ topic_id: topic.id })
  end

  it "detects locale" do
    allow(DiscourseAi::Translation::TopicLocaleDetector).to receive(:detect_locale).with(
      topic,
    ).and_return("zh_CN")
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).twice

    job.execute({ topic_id: topic.id })
  end

  it "skips locale detection when topic has a locale" do
    topic.update!(locale: "en")
    DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).with(topic).never
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(topic, "ja").once

    job.execute({ topic_id: topic.id })
  end

  it "skips bot topics by default" do
    topic.update!(user: Discourse.system_user)
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

    job.execute({ topic_id: topic.id })
  end

  it "translates bot topics when force is true" do
    topic.update!(user: Discourse.system_user)
    DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).once

    job.execute({ topic_id: topic.id, force: true })
  end

  it "translates bot topics when ai_translation_include_bot_content is true" do
    SiteSetting.ai_translation_include_bot_content = true
    topic.update!(user: Discourse.system_user)
    DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).once

    job.execute({ topic_id: topic.id })
  end

  it "does not get locale or translate when no target languages are configured" do
    SiteSetting.content_localization_supported_locales = ""
    DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).never
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

    job.execute({ topic_id: topic.id })
  end

  it "skips translating to the topic's language" do
    topic.update(locale: "en")
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(topic, "en").never
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(topic, "ja").once

    job.execute({ topic_id: topic.id })
  end

  context "when translation exists and retranslation quota hit" do
    before do
      DiscourseAi::Translation::TopicLocalizer
        .expects(:has_relocalize_quota?)
        .with(topic, "ja")
        .returns(false)
    end

    it "skips translating if the topic is already localized" do
      topic.update(locale: "en")
      Fabricate(:topic_localization, topic:, locale: "ja")

      DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

      job.execute({ topic_id: topic.id })
    end

    it "does not translate to language of similar variant" do
      topic.update(locale: "en_GB")
      Fabricate(:topic_localization, topic:, locale: "ja_JP")

      DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

      job.execute({ topic_id: topic.id })
    end

    it "translates when force is true" do
      topic.update(locale: "en")
      Fabricate(:topic_localization, topic:, locale: "ja")

      DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(topic, "ja").once

      job.execute({ topic_id: topic.id, force: true })
    end
  end

  it "handles translation errors gracefully" do
    topic.update(locale: "en")
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).raises(
      StandardError.new("API error"),
    )

    expect { job.execute({ topic_id: topic.id }) }.not_to raise_error
  end

  describe "with category scope and PM scope" do
    fab!(:included_category, :category)
    fab!(:excluded_category, :category)
    fab!(:included_topic) { Fabricate(:topic, category: included_category) }
    fab!(:excluded_topic) { Fabricate(:topic, category: excluded_category) }

    fab!(:personal_pm_topic, :private_message_topic)

    fab!(:group_pm_topic) do
      Fabricate(:group_private_message_topic, recipient_group: Fabricate(:group))
    end

    before do
      SiteSetting.ai_translation_category_scope = "exclude"
      SiteSetting.ai_translation_categories = excluded_category.id.to_s
    end

    it "skips topics outside the category scope" do
      DiscourseAi::Translation::TopicLocaleDetector
        .expects(:detect_locale)
        .with(excluded_topic)
        .never

      job.execute({ topic_id: excluded_topic.id })
    end

    it "processes topics in included categories" do
      DiscourseAi::Translation::TopicLocaleDetector
        .expects(:detect_locale)
        .with(included_topic)
        .once

      job.execute({ topic_id: included_topic.id })
    end

    it "processes regular topics when all categories are configured" do
      SiteSetting.ai_translation_category_scope = "all"
      SiteSetting.ai_translation_categories = ""

      DiscourseAi::Translation::TopicLocaleDetector
        .expects(:detect_locale)
        .with(included_topic)
        .once

      job.execute({ topic_id: included_topic.id })
    end

    it "skips subcategory topics in strict include mode" do
      subcategory = Fabricate(:category, parent_category: included_category)
      subcategory_topic = Fabricate(:topic, category: subcategory)
      SiteSetting.ai_translation_category_scope = "include_strict"
      SiteSetting.ai_translation_categories = included_category.id.to_s

      DiscourseAi::Translation::TopicLocaleDetector
        .expects(:detect_locale)
        .with(subcategory_topic)
        .never

      job.execute({ topic_id: subcategory_topic.id })
    end

    context "when pm_translation_scope is none" do
      before { SiteSetting.ai_translation_personal_messages = "none" }

      it "skips all PMs" do
        DiscourseAi::Translation::TopicLocaleDetector
          .expects(:detect_locale)
          .with(personal_pm_topic)
          .never
        job.execute({ topic_id: personal_pm_topic.id })

        DiscourseAi::Translation::TopicLocaleDetector
          .expects(:detect_locale)
          .with(group_pm_topic)
          .never
        job.execute({ topic_id: group_pm_topic.id })
      end
    end

    context "when pm_translation_scope is group" do
      before { SiteSetting.ai_translation_personal_messages = "group" }

      it "processes group PMs but skips personal PMs" do
        DiscourseAi::Translation::TopicLocaleDetector
          .expects(:detect_locale)
          .with(group_pm_topic)
          .once
        job.execute({ topic_id: group_pm_topic.id })

        DiscourseAi::Translation::TopicLocaleDetector
          .expects(:detect_locale)
          .with(personal_pm_topic)
          .never
        job.execute({ topic_id: personal_pm_topic.id })
      end
    end

    context "when pm_translation_scope is all" do
      before { SiteSetting.ai_translation_personal_messages = "all" }

      it "processes all PMs" do
        DiscourseAi::Translation::TopicLocaleDetector
          .expects(:detect_locale)
          .with(group_pm_topic)
          .once
        job.execute({ topic_id: group_pm_topic.id })

        DiscourseAi::Translation::TopicLocaleDetector
          .expects(:detect_locale)
          .with(personal_pm_topic)
          .once
        job.execute({ topic_id: personal_pm_topic.id })
      end
    end

    describe "force arg" do
      it "processes private content when force is true" do
        DiscourseAi::Translation::TopicLocaleDetector
          .expects(:detect_locale)
          .with(group_pm_topic)
          .once

        job.execute({ topic_id: group_pm_topic.id, force: true })
      end

      it "processes PM content when force is true" do
        DiscourseAi::Translation::TopicLocaleDetector
          .expects(:detect_locale)
          .with(personal_pm_topic)
          .once

        job.execute({ topic_id: personal_pm_topic.id, force: true })
      end
    end

    it "publishes a MessageBus event to update the topic" do
      SiteSetting.ai_translation_personal_messages = "all"

      allow(DiscourseAi::Translation::TopicLocaleDetector).to receive(:detect_locale).with(
        group_pm_topic,
      ).and_return("en")
      allow(DiscourseAi::Translation::TopicLocalizer).to receive(:localize).and_return(true)

      message =
        MessageBus.track_publish { job.execute({ topic_id: group_pm_topic.id, force: true }) }

      expect(message.count).to eq(1)
      expect(message.first.channel).to eq("/topic/#{group_pm_topic.id}")
      expect(message.first.data).to eq(reload_topic: true)
    end
  end
end
