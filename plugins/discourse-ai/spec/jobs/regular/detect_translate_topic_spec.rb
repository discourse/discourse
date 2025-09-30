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

  it "skips bot topics" do
    topic.update!(user: Discourse.system_user)
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

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

  it "skips translating if the topic is already localized" do
    topic.update(locale: "en")
    Fabricate(:topic_localization, topic:, locale: "ja")
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

    job.execute({ topic_id: topic.id })
  end

  it "does not translate to language of similar variant" do
    topic.update(locale: "en_GB")
    Fabricate(:topic_localization, topic:, locale: "ja_JP")

    DiscourseAi::Translation::PostLocalizer.expects(:localize).never

    job.execute({ topic_id: topic.id })
  end

  it "handles translation errors gracefully" do
    topic.update(locale: "en")
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).raises(
      StandardError.new("API error"),
    )

    expect { job.execute({ topic_id: topic.id }) }.not_to raise_error
  end

  describe "with public content and PM limitations" do
    fab!(:private_category) { Fabricate(:private_category, group: Group[:staff]) }
    fab!(:private_topic) { Fabricate(:topic, category: private_category) }

    fab!(:personal_pm_topic) { Fabricate(:private_message_topic) }

    fab!(:group_pm_topic) do
      Fabricate(:group_private_message_topic, recipient_group: Fabricate(:group))
    end

    context "when ai_translation_backfill_limit_to_public_content is true" do
      before { SiteSetting.ai_translation_backfill_limit_to_public_content = true }

      it "skips topics from restricted categories and PMs" do
        DiscourseAi::Translation::TopicLocaleDetector
          .expects(:detect_locale)
          .with(private_topic)
          .never
        DiscourseAi::Translation::TopicLocalizer
          .expects(:localize)
          .with(private_topic, any_parameters)
          .never
        job.execute({ topic_id: private_topic.id })

        # Skip personal PMs
        DiscourseAi::Translation::TopicLocaleDetector
          .expects(:detect_locale)
          .with(personal_pm_topic)
          .never
        DiscourseAi::Translation::TopicLocalizer
          .expects(:localize)
          .with(personal_pm_topic, any_parameters)
          .never
        job.execute({ topic_id: personal_pm_topic.id })

        DiscourseAi::Translation::TopicLocaleDetector
          .expects(:detect_locale)
          .with(group_pm_topic)
          .never
        DiscourseAi::Translation::TopicLocalizer
          .expects(:localize)
          .with(group_pm_topic, any_parameters)
          .never

        job.execute({ topic_id: group_pm_topic.id })
      end
    end

    context "when ai_translation_backfill_limit_to_public_content is false" do
      before { SiteSetting.ai_translation_backfill_limit_to_public_content = false }

      it "processes topics from private categories and group PMs but skips personal PMs" do
        DiscourseAi::Translation::TopicLocaleDetector
          .expects(:detect_locale)
          .with(private_topic)
          .once
        job.execute({ topic_id: private_topic.id })

        DiscourseAi::Translation::TopicLocaleDetector
          .expects(:detect_locale)
          .with(group_pm_topic)
          .once
        job.execute({ topic_id: group_pm_topic.id })

        DiscourseAi::Translation::TopicLocaleDetector
          .expects(:detect_locale)
          .with(personal_pm_topic)
          .never
        DiscourseAi::Translation::TopicLocalizer
          .expects(:localize)
          .with(personal_pm_topic, any_parameters)
          .never
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
