# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Actions::CreateTopic do
  fab!(:admin)
  fab!(:category)

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.tagging_enabled = true
  end

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("action:create_topic")
    end
  end

  describe "#execute_single" do
    let(:action) { described_class.new(configuration: {}) }
    let(:item) { { "json" => {} } }

    it "creates a topic for the configured user" do
      result = nil

      expect do
        result =
          action.execute_single(
            {},
            item: item,
            config: {
              "title" => "Workflow topic",
              "raw" => "First post body",
              "category_id" => category.id.to_s,
              "user_id" => admin.id.to_s,
            },
          )
      end.to change(Topic, :count).by(1).and change(Post, :count).by(1)

      topic = Topic.last

      expect(topic.title).to eq("Workflow topic")
      expect(topic.first_post.raw).to eq("First post body")
      expect(topic.category_id).to eq(category.id)
      expect(topic.user_id).to eq(admin.id)

      expect(result).to include(
        topic_id: topic.id,
        topic_title: topic.title,
        topic_raw: "First post body",
        category_id: category.id,
        user_id: admin.id,
        username: admin.username,
        archetype: Archetype.default,
        post_id: topic.first_post.id,
        post_number: 1,
      )
    end

    it "falls back to the system user when no user is configured" do
      action.execute_single(
        {},
        item: item,
        config: {
          "title" => "System topic",
          "raw" => "Created by workflows",
        },
      )

      expect(Topic.last.user_id).to eq(Discourse.system_user.id)
    end

    it "accepts tags from an array" do
      action.execute_single(
        {},
        item: item,
        config: {
          "title" => "Tagged topic",
          "raw" => "With tags",
          "tag_names" => ["alpha", " beta "],
        },
      )

      expect(Topic.last.tags.pluck(:name)).to contain_exactly("alpha", "beta")
    end

    it "raises when the user cannot be found" do
      expect do
        action.execute_single(
          {},
          item: item,
          config: {
            "title" => "Workflow topic",
            "raw" => "First post body",
            "user_id" => -999,
          },
        )
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "raises when topic creation fails validation" do
      expect do
        action.execute_single({}, item: item, config: { "title" => "", "raw" => "" })
      end.to raise_error(ActiveRecord::RecordNotSaved)
    end
  end
end
