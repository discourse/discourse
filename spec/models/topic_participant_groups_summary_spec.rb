# frozen_string_literal: true

RSpec.describe TopicParticipantGroupsSummary do
  describe "#summary" do
    fab!(:group1) { Fabricate(:group) }
    fab!(:group2) { Fabricate(:group) }
    fab!(:group3) { Fabricate(:group) }

    let(:topic) { Fabricate(:private_message_topic) }

    it "must contain the name of allowed groups" do
      topic.allowed_group_ids = [group1.id, group2.id, group3.id]
      expect(described_class.new(topic, group: group1).summary).to eq([group2.name, group3.name])
      expect(described_class.new(topic, group: group2).summary).to eq([group1.name, group3.name])
    end
  end
end
