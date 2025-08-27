# frozen_string_literal: true

describe ListableTopicSerializer do
  fab!(:topic)

  describe "#excerpt" do
    before { topic.update!(excerpt: "This is excerrrpt-ional") }

    it "can be included by theme modifiers" do
      payload = TopicListItemSerializer.new(topic, scope: Guardian.new, root: false).as_json

      expect(payload[:excerpt]).to eq(nil)

      theme = Fabricate(:theme)

      child_theme =
        Fabricate(:theme, component: true).tap { |t| theme.add_relative_theme!(:child, t) }

      child_theme.theme_modifier_set.serialize_topic_excerpts = true
      child_theme.save!

      request = ActionController::TestRequest.new({ resolved_theme_id: theme.id }, nil, nil)

      guardian = Guardian.new(nil, request)

      payload = TopicListItemSerializer.new(topic, scope: guardian, root: false).as_json

      expect(payload[:excerpt]).to eq(topic.excerpt)
    end

    it "does not include the excerpt by default" do
      json = ListableTopicSerializer.new(topic, scope: Guardian.new).as_json

      expect(json[:listable_topic][:excerpt]).to eq(nil)
    end

    it "returns the topic's excerpt" do
      SiteSetting.always_include_topic_excerpts = true
      json = ListableTopicSerializer.new(topic, scope: Guardian.new).as_json

      expect(json[:listable_topic][:excerpt]).to eq("This is excerrrpt-ional")
    end

    it "returns the localized excerpt when setting is enabled" do
      I18n.locale = "ja"
      topic.update!(locale: "en")
      Fabricate(:topic_localization, topic:, excerpt: "X", locale: "ja")

      SiteSetting.content_localization_enabled = true
      SiteSetting.always_include_topic_excerpts = true

      json = ListableTopicSerializer.new(topic, scope: Guardian.new).as_json

      expect(json[:listable_topic][:excerpt]).to eq("X")
    end
  end
end
