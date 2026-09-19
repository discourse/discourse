# frozen_string_literal: true

RSpec.describe JsonApiKit::Association::Through do
  subject(:association) { JsonApiKit::Schema.new(Topic).association(:tags, owner_rows) }

  fab!(:topic) { Fabricate(:topic, title: "A topic another table pairs with tags") }
  fab!(:another_topic) { Fabricate(:topic, title: "A topic that carries the same tag") }
  fab!(:untagged_topic) { Fabricate(:topic, title: "A topic the other table never names") }
  fab!(:shared_tag) { Fabricate(:tag, name: "the-tag-two-topics-carry") }
  fab!(:own_tag) { Fabricate(:tag, name: "the-tag-one-topic-carries") }
  fab!(:other_tag) { Fabricate(:tag, name: "the-tag-no-topic-carries") }
  fab!(:shared_tagging) { Fabricate(:topic_tag, topic:, tag: shared_tag) }
  fab!(:own_tagging) { Fabricate(:topic_tag, topic:, tag: own_tag) }
  fab!(:another_tagging) { Fabricate(:topic_tag, topic: another_topic, tag: shared_tag) }

  let(:owner_rows) { [topic, another_topic, untagged_topic] }

  describe "#related_scope" do
    subject(:related_scope) { association.related_scope }

    it "returns each row it reaches only once" do
      expect(related_scope).to contain_exactly(shared_tag, own_tag)
    end

    it "returns rows that hold only their own columns" do
      expect(related_scope.first.attributes.keys).to eq(Tag.column_names)
    end
  end

  describe "#pair" do
    subject(:pairs) { association.pair([own_tag, shared_tag, other_tag]) }

    it "pairs each owner row with the rows it reaches" do
      expect(pairs).to include(topic => [own_tag, shared_tag], another_topic => [shared_tag])
    end

    it "returns nothing for a row with no pair" do
      expect(pairs).to include(untagged_topic => [])
    end
  end
end
