# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization do
  fab!(:topic)
  fab!(:user)

  before { enable_current_plugin }

  describe ".gist_locales" do
    it "returns the source locale when content localization is disabled" do
      topic.update!(locale: "es")
      SiteSetting.content_localization_enabled = false

      expect(described_class.gist_locales(topic)).to eq(["es"])
    end

    it "returns configured locales plus a distinct source locale" do
      topic.update!(locale: "fr")
      SiteSetting.content_localization_enabled = true
      SiteSetting.content_localization_supported_locales = "en|ja"

      expect(described_class.gist_locales(topic)).to eq(%w[en ja fr])
    end

    it "deduplicates equivalent regional locales" do
      topic.update!(locale: "en_GB")
      SiteSetting.content_localization_enabled = true
      SiteSetting.content_localization_supported_locales = "en|ja"

      expect(described_class.gist_locales(topic)).to eq(%w[en ja])
    end

    it "normalizes generated locale identifiers" do
      topic.update!(locale: "pt-br")
      SiteSetting.content_localization_enabled = false

      expect(described_class.gist_locales(topic)).to eq(["pt_BR"])
    end

    it "selects the source locale rather than the first configured locale" do
      topic.update!(locale: "ja")
      SiteSetting.content_localization_enabled = true
      SiteSetting.content_localization_supported_locales = "en|ja"

      expect(described_class.gist_source_locale(topic)).to eq("ja")
    end
  end

  describe ".display_locale" do
    it "uses only configured content locales or the topic source locale" do
      topic.update!(locale: "fr")
      SiteSetting.content_localization_enabled = true
      SiteSetting.content_localization_supported_locales = "en|he|pt_BR"

      unsupported_locale =
        I18n.with_locale(:ja) { described_class.display_locale(topic, scope: user.guardian) }
      regional_match =
        I18n.with_locale(:pt) { described_class.display_locale(topic, scope: user.guardian) }

      expect(unsupported_locale).to eq("fr")
      expect(regional_match).to eq("pt_BR")
    end
  end

  describe ".gist_for" do
    it "returns only a gist matching the requested locale" do
      topic.update!(locale: "fr")
      Fabricate(:topic_ai_gist, target: topic, locale: "en", summarized_text: "English gist")
      Fabricate(:topic_ai_gist, target: topic, locale: "fr", summarized_text: "Résumé français")
      SiteSetting.content_localization_enabled = true
      SiteSetting.content_localization_supported_locales = "de"
      I18n.locale = :de

      expect(described_class.gist_for(topic, scope: user.guardian)).to be_nil

      german_gist =
        Fabricate(
          :topic_ai_gist,
          target: topic,
          locale: "de",
          summarized_text: "Deutsche Zusammenfassung",
        )
      topic.ai_gist_summaries.reset
      expect(described_class.gist_for(topic, scope: user.guardian)).to eq(german_gist)
    end

    it "returns the source-locale gist when the user requests original content" do
      topic.update!(locale: "fr")
      source_gist =
        Fabricate(:topic_ai_gist, target: topic, locale: "fr", summarized_text: "Résumé français")
      Fabricate(
        :topic_ai_gist,
        target: topic,
        locale: "de",
        summarized_text: "Deutsche Zusammenfassung",
      )
      SiteSetting.content_localization_enabled = true
      I18n.locale = :de
      user.user_option.update!(show_original_content: true)

      expect(described_class.gist_for(topic, scope: user.guardian)).to eq(source_gist)
    end

    it "does not use a legacy locale-less gist as a fallback" do
      Fabricate(:topic_ai_gist, target: topic, locale: nil)
      SiteSetting.content_localization_enabled = true
      I18n.locale = :ja

      expect(described_class.gist_for(topic, scope: user.guardian)).to be_nil
    end
  end
end
