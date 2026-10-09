# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicModeration::V1 do
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:user)

  describe ".property_schema" do
    it "declares a fixed unlist topic operation" do
      expect(described_class.property_schema[:operation]).to include(
        type: :options,
        options: ["unlist_topic"],
        default: "unlist_topic",
        ui: {
          expression: false,
        },
      )
    end
  end

  describe "#execute" do
    it "unlists a topic as the system user", :aggregate_failures do
      result = nil

      expect do
        result =
          execute_node(
            configuration: {
              "operation" => "unlist_topic",
              "topic_id" => topic.id.to_s,
            },
          )
      end.to change { topic.reload.posts.count }.by(1)

      topic.reload
      expect(topic.visible).to eq(false)
      expect(topic.visibility_reason_id).to eq(Topic.visibility_reasons[:manually_unlisted])
      expect(topic.posts.last).to have_attributes(
        action_code: "visible.disabled",
        user_id: Discourse.system_user.id,
      )
      expect(result["topic"]).to include(
        "id" => topic.id,
        "visible" => false,
        "visibility_reason_id" => Topic.visibility_reasons[:manually_unlisted],
      )
      expect(result).to match_node_output_schema(described_class)
    end

    it "allows a category group moderator to unlist a topic" do
      group = Fabricate(:group)
      group_moderator = Fabricate(:user)
      group.add(group_moderator)
      Fabricate(:category_moderation_group, category: category, group: group)
      SiteSetting.enable_category_group_moderation = true

      execute_node(
        configuration: {
          "operation" => "unlist_topic",
          "topic_id" => topic.id.to_s,
          "actor_username" => group_moderator.username,
        },
      )

      expect(topic.reload.visible).to eq(false)
      expect(topic.posts.last.user_id).to eq(group_moderator.id)
    end

    it "rejects an actor without permission" do
      expect do
        execute_node(
          configuration: {
            "operation" => "unlist_topic",
            "topic_id" => topic.id.to_s,
            "actor_username" => user.username,
          },
        )
      end.to raise_error(Discourse::InvalidAccess)

      expect(topic.reload.visible).to eq(true)
    end

    it "does not create another action post when the topic is already unlisted" do
      topic.update!(
        visible: false,
        visibility_reason_id: Topic.visibility_reasons[:manually_unlisted],
      )
      result = nil

      expect do
        result =
          execute_node(
            configuration: {
              "operation" => "unlist_topic",
              "topic_id" => topic.id.to_s,
            },
          )
      end.not_to change { topic.reload.posts.count }

      expect(result.dig("topic", "visible")).to eq(false)
    end

    it "unlists each input item's topic separately" do
      second_topic = Fabricate(:topic)

      output =
        execute_node_output(
          configuration: {
            "operation" => "unlist_topic",
            "topic_id" => "={{ $json.topic_id }}",
          },
          input_items: [
            { "json" => { "topic_id" => topic.id } },
            { "json" => { "topic_id" => second_topic.id } },
          ],
        ).first

      expect(output.map { |item| item.dig("json", "topic", "id") }).to eq(
        [topic.id, second_topic.id],
      )
      expect([topic.reload.visible, second_topic.reload.visible]).to eq([false, false])
    end

    it "raises on an unknown operation" do
      expect do
        execute_node(configuration: { "operation" => "delete_topic", "topic_id" => topic.id.to_s })
      end.to raise_error(DiscourseWorkflows::NodeError, "Unknown operation: delete_topic.")

      expect(topic.reload.visible).to eq(true)
    end
  end
end
