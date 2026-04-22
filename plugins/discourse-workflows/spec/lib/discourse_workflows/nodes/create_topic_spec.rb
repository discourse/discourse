# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::CreateTopic::V1 do
  fab!(:admin)
  fab!(:category)

  before { SiteSetting.tagging_enabled = true }

  describe "#execute" do
    let(:item) { { "json" => {} } }

    it "creates a topic for the configured user" do
      result = nil

      expect do
        result =
          execute_node(
            configuration: {
              "title" => "Workflow topic",
              "raw" => "First post body",
              "category_id" => category.id.to_s,
              "username" => admin.username,
            },
            item: item,
          )
      end.to change(Topic, :count).by(1).and change(Post, :count).by(1)

      topic = Topic.last

      expect(topic.title).to eq("Workflow topic")
      expect(topic.first_post.raw).to eq("First post body")
      expect(topic.category_id).to eq(category.id)
      expect(topic.user_id).to eq(admin.id)

      expect(result["topic"]).to include(
        "id" => topic.id,
        "title" => topic.title,
        "raw" => "First post body",
        "category_id" => category.id,
        "user_id" => admin.id,
        "username" => admin.username,
        "archetype" => Archetype.default,
      )
      expect(result).to include("post_id" => topic.first_post.id, "post_number" => 1)
    end

    it "creates a topic as the system user when the username is 'system'" do
      execute_node(
        configuration: {
          "title" => "System topic",
          "raw" => "Created by workflows",
          "username" => "system",
        },
        item: item,
      )

      expect(Topic.last.user_id).to eq(Discourse.system_user.id)
    end

    it "accepts tags from an array" do
      execute_node(
        configuration: {
          "title" => "Tagged topic",
          "raw" => "With tags",
          "tag_names" => ["alpha", " beta "],
          "username" => "system",
        },
        item: item,
      )

      expect(Topic.last.tags.pluck(:name)).to contain_exactly("alpha", "beta")
    end

    it "raises when the user cannot be found" do
      expect do
        execute_node(
          configuration: {
            "title" => "Workflow topic",
            "raw" => "First post body",
            "username" => "nonexistent_user",
          },
          item: item,
        )
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "raises when topic creation fails validation" do
      expect do
        execute_node(
          configuration: {
            "title" => "",
            "raw" => "",
            "username" => "system",
          },
          item: item,
        )
      end.to raise_error(RuntimeError)
    end
  end
end
