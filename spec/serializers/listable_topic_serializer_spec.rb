# frozen_string_literal: true
RSpec.describe ListableTopicSerializer do
  fab!(:topic) { Fabricate(:topic) }

  describe "#excerpt" do
    it "can be extended by theme modifiers" do
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
  end
end
