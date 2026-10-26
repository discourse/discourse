# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::CloseTopic::V1 do
  fab!(:topic)
  fab!(:moderator)
  fab!(:user)

  describe "#execute" do
    it "closes the topic as the actor and reports the change", :aggregate_failures do
      result = nil

      expect do
        result =
          execute_node(
            configuration: {
              "topic_id" => topic.id.to_s,
              "actor_username" => moderator.username,
            },
          )
      end.to change { topic.reload.posts.count }.by(1)

      expect(topic).to be_closed
      expect(topic.posts.last).to have_attributes(action_code: "closed.enabled", user: moderator)
      expect(result).to include(
        "changed" => true,
        "topic" => include("id" => topic.id, "closed" => true),
      )
      expect(result).to match_node_output_schema(described_class)
    end

    it "succeeds without a change when the topic is already closed" do
      topic.update!(closed: true)
      result = nil

      expect do
        result = execute_node(configuration: { "topic_id" => topic.id.to_s })
      end.not_to change { topic.reload.posts.count }

      expect(result).to include("changed" => false)
    end

    it "rejects an actor who can't close the topic" do
      expect do
        execute_node(
          configuration: {
            "topic_id" => topic.id.to_s,
            "actor_username" => user.username,
          },
        )
      end.to raise_error(Discourse::InvalidAccess)

      expect(topic.reload).not_to be_closed
    end
  end
end

RSpec.describe DiscourseWorkflows::Nodes::ReopenTopic::V1 do
  fab!(:topic) { Fabricate(:topic, closed: true) }

  it "reopens a closed topic" do
    result = execute_node(configuration: { "topic_id" => topic.id.to_s })

    expect(topic.reload).not_to be_closed
    expect(result).to include("changed" => true)
  end
end

RSpec.describe DiscourseWorkflows::Nodes::ArchiveTopic::V1 do
  fab!(:topic)

  it "archives the topic" do
    result = execute_node(configuration: { "topic_id" => topic.id.to_s })

    expect(topic.reload).to be_archived
    expect(result).to include("changed" => true)
  end
end

RSpec.describe DiscourseWorkflows::Nodes::UnarchiveTopic::V1 do
  fab!(:topic) { Fabricate(:topic, archived: true) }

  it "unarchives an archived topic" do
    result = execute_node(configuration: { "topic_id" => topic.id.to_s })

    expect(topic.reload).not_to be_archived
    expect(result).to include("changed" => true)
  end
end

RSpec.describe DiscourseWorkflows::Nodes::UnlistTopic::V1 do
  fab!(:topic)

  it "unlists the topic as manually unlisted" do
    result = execute_node(configuration: { "topic_id" => topic.id.to_s })

    expect(topic.reload).to have_attributes(
      visible: false,
      visibility_reason_id: Topic.visibility_reasons[:manually_unlisted],
    )
    expect(result).to include("changed" => true)
  end
end

RSpec.describe DiscourseWorkflows::Nodes::ListTopic::V1 do
  fab!(:topic) do
    Fabricate(
      :topic,
      visible: false,
      visibility_reason_id: Topic.visibility_reasons[:manually_unlisted],
    )
  end

  it "lists an unlisted topic as manually relisted" do
    result = execute_node(configuration: { "topic_id" => topic.id.to_s })

    expect(topic.reload).to have_attributes(
      visible: true,
      visibility_reason_id: Topic.visibility_reasons[:manually_relisted],
    )
    expect(result).to include("changed" => true)
  end
end
