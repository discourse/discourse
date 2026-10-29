# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicBannered::V1 do
  fab!(:admin)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category:) }

  describe "#output" do
    it "returns the topic and the actor", :aggregate_failures do
      output = described_class.new(topic, acting_user: admin).output

      expect(output[:topic]).to include(id: topic.id, title: topic.title)
      expect(output[:actor]).to include(id: admin.id, username: admin.username)
      expect(output).to match_node_output_schema(described_class)
    end

    it "returns a null actor when the event carries none" do
      output = described_class.new(topic).output

      expect(output[:actor]).to be_nil
      expect(output).to match_node_output_schema(described_class)
    end

    it "builds from the event make_banner! fires" do
      event = DiscourseEvent.track(:topic_bannered) { topic.make_banner!(admin) }

      expect(described_class.new(*event[:params]).output).to include(
        topic: include(id: topic.id),
        actor: include(id: admin.id),
      )
    end
  end

  describe "#matches?" do
    it "matches the configured categories" do
      trigger = described_class.new(topic, acting_user: admin)

      expect(trigger.matches?(trigger_context("category_ids" => [category.id.to_s]))).to eq(true)
      expect(
        trigger.matches?(trigger_context("category_ids" => [Fabricate(:category).id.to_s])),
      ).to eq(false)
    end
  end
end

RSpec.describe DiscourseWorkflows::Nodes::TopicUnbannered::V1 do
  fab!(:admin)
  fab!(:topic)

  describe "#output" do
    it "returns the topic and the actor", :aggregate_failures do
      output = described_class.new(topic, acting_user: admin).output

      expect(output[:topic]).to include(id: topic.id)
      expect(output[:actor]).to include(id: admin.id)
      expect(output).to match_node_output_schema(described_class)
    end

    it "builds from the event fired when the banner expires, as the system user" do
      topic.make_banner!(admin)

      event =
        DiscourseEvent.track(:topic_unbannered) do
          Jobs::RemoveBanner.new.execute(topic_id: topic.id)
        end

      expect(described_class.new(*event[:params]).output[:actor]).to include(
        id: Discourse.system_user.id,
      )
    end
  end
end
