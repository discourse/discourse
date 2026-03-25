# frozen_string_literal: true

RSpec.describe NestedReplies do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)
  fab!(:nested_category) { Fabricate(:category, name: "Nested Category") }

  before do
    SiteSetting.nested_replies_enabled = true
    nested_category.category_setting.update!(nested_replies_default: true)
  end

  describe "topic_created event" do
    it "sets the nested field when category has nested default enabled" do
      post =
        PostCreator.create!(
          user,
          title: "Test nested topic in category",
          raw: "This is a test topic in a nested category",
          category: nested_category.id,
        )

      expect(post.topic.reload.nested_topic).to be_present
    end

    it "sets the nested field when global nested_replies_default is enabled" do
      SiteSetting.nested_replies_default = true

      post =
        PostCreator.create!(
          user,
          title: "Test nested topic globally",
          raw: "This is a test topic with global nested default",
          category: category.id,
        )

      expect(post.topic.reload.nested_topic).to be_present
    end

    it "does not set the nested field for topics in regular categories" do
      post =
        PostCreator.create!(
          user,
          title: "Test normal topic",
          raw: "This is a test topic in a regular category",
          category: category.id,
        )

      expect(post.topic.reload.nested_topic).to be_nil
    end

    it "does not set the nested field when plugin is disabled" do
      SiteSetting.nested_replies_enabled = false

      post =
        PostCreator.create!(
          user,
          title: "Test topic plugin disabled",
          raw: "This is a test topic with plugin disabled",
          category: nested_category.id,
        )

      expect(post.topic.reload.nested_topic).to be_nil
    end
  end

  describe "serialization" do
    fab!(:topic) { Fabricate(:topic, user: user, category: nested_category) }
    fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

    before { NestedTopic.create!(topic: topic) }

    it "includes is_nested_view on TopicListItemSerializer" do
      json = TopicListItemSerializer.new(topic, scope: Guardian.new(user), root: false).as_json

      expect(json[:is_nested_view]).to eq(true)
    end

    it "includes is_nested_view on TopicViewSerializer" do
      topic_view = TopicView.new(topic.id, user)
      json = TopicViewSerializer.new(topic_view, scope: Guardian.new(user), root: false).as_json

      expect(json[:is_nested_view]).to eq(true)
    end

    it "returns false for is_nested_view when not set" do
      topic.nested_topic&.destroy!

      topic_view = TopicView.new(topic.id, user)
      json = TopicViewSerializer.new(topic_view, scope: Guardian.new(user), root: false).as_json

      expect(json[:is_nested_view]).to eq(false)
    end
  end
end
