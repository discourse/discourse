# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicPublished::V1 do
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category:) }
  fab!(:moderator)

  let(:published_at) { Time.zone.now }

  describe "#output" do
    it "returns the topic, when it was published and the actor", :aggregate_failures do
      output = described_class.new(topic, published_at, acting_user: moderator).output

      expect(output[:topic]).to include(id: topic.id, title: topic.title)
      expect(output[:published_at]).to eq(published_at.iso8601)
      expect(output[:actor]).to include(id: moderator.id, username: moderator.username)
      expect(output).to match_node_output_schema(described_class)
    end

    it "returns a null actor when the event carries none" do
      output = described_class.new(topic, published_at).output

      expect(output[:actor]).to be_nil
      expect(output).to match_node_output_schema(described_class)
    end

    it "builds from the event TopicPublisher fires" do
      shared_drafts_category = Fabricate(:category)
      SiteSetting.shared_drafts_category = shared_drafts_category.id
      draft = Fabricate(:topic, category: shared_drafts_category, visible: false)
      Fabricate(:post, topic: draft)
      Fabricate(:shared_draft, topic: draft, category:)

      event =
        DiscourseEvent.track(:topic_published) do
          TopicPublisher.new(draft, moderator, category.id).publish!
        end

      expect(described_class.new(*event[:params]).output[:actor]).to include(id: moderator.id)
    end
  end

  describe "#matches?" do
    it "matches the configured categories" do
      trigger = described_class.new(topic, published_at)

      expect(trigger.matches?(trigger_context("category_ids" => [category.id.to_s]))).to eq(true)
      expect(
        trigger.matches?(trigger_context("category_ids" => [Fabricate(:category).id.to_s])),
      ).to eq(false)
    end
  end
end
