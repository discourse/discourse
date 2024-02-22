# frozen_string_literal: true

RSpec.describe TopicTag do
  fab!(:group)
  fab!(:private_category) { Fabricate(:private_category, group: group) }
  fab!(:topic)
  fab!(:topic_in_private_category) { Fabricate(:topic, category: private_category) }
  fab!(:tag)
  let(:topic_tag) { Fabricate(:topic_tag, topic: topic, tag: tag) }

  describe "#after_create" do
    it "should increase Tag#staff_topic_count and Tag#public_topic_count for a regular topic in a public category" do
      expect { topic_tag }.to change { tag.reload.staff_topic_count }.by(1).and change {
              tag.reload.public_topic_count
            }.by(1)
    end

    it "should only increase Tag#staff_topic_count for a regular topic in a read restricted category" do
      expect { Fabricate(:topic_tag, topic: topic_in_private_category, tag: tag) }.to change {
        tag.reload.staff_topic_count
      }.by(1)

      expect(tag.reload.public_topic_count).to eq(0)
    end

    it "should increase Tag#pm_topic_count for a private message topic" do
      topic.archetype = Archetype.private_message

      expect { topic_tag }.to change { tag.reload.pm_topic_count }.by(1)
    end
  end

  describe "#after_destroy" do
    it "should decrease Tag#staff_topic_count and Tag#public_topic_count for a regular topic in a public category" do
      topic_tag

      expect { topic_tag.destroy! }.to change { tag.reload.staff_topic_count }.by(-1).and change {
              tag.reload.public_topic_count
            }.by(-1)
    end

    it "should only decrease Topic#topic_count for a regular topic in a read restricted category" do
      topic_tag = Fabricate(:topic_tag, topic: topic_in_private_category, tag: tag)

      expect { topic_tag.destroy! }.to change { tag.reload.staff_topic_count }.by(-1)
      expect(tag.reload.public_topic_count).to eq(0)
    end

    it "should decrease Tag#pm_topic_count for a private message topic" do
      topic.archetype = Archetype.private_message
      topic_tag

      expect { topic_tag.destroy! }.to change { tag.reload.pm_topic_count }.by(-1)
    end
  end
end
