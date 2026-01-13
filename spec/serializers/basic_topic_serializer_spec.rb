# frozen_string_literal: true

describe BasicTopicSerializer do
  fab!(:topic) { Fabricate(:topic, title: "Hur dur this is a title") }

  describe "#fancy_title" do
    it "returns the fancy title" do
      json = BasicTopicSerializer.new(topic).as_json

      expect(json[:basic_topic][:fancy_title]).to eq(topic.title)
    end

    describe "localizations" do
      it "returns the fancy title with a modifier" do
        SiteSetting.content_localization_enabled = true
        Fabricate(:topic_localization, topic:, fancy_title: "X", locale: "ja")
        I18n.locale = "ja"
        topic.update!(locale: "en")

        json = BasicTopicSerializer.new(topic).as_json

        expect(json[:basic_topic][:fancy_title]).to eq("X")
      end

      it "returns the site default locale fancy title when no exact match found and `content_localization_use_default_locale_when_unsupported` is true" do
        SiteSetting.content_localization_enabled = true
        SiteSetting.content_localization_use_default_locale_when_unsupported = true
        SiteSetting.default_locale = "el"

        Fabricate(
          :topic_localization,
          topic:,
          fancy_title: "site default fancy title",
          locale: "el",
        )
        I18n.locale = "ja"
        topic.update!(locale: "en")

        json = BasicTopicSerializer.new(topic).as_json

        expect(json[:basic_topic][:fancy_title]).to eq("site default fancy title")
      end
    end
  end
end
