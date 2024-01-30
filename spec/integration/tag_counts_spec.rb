# frozen_string_literal: true

RSpec.describe "Updating tag counts" do
  fab!(:tag1) { Fabricate(:tag) }
  fab!(:tag2) { Fabricate(:tag) }
  fab!(:group)
  fab!(:public_category) { Fabricate(:category) }
  fab!(:public_category2) { Fabricate(:category) }
  fab!(:private_category) { Fabricate(:private_category, group: group) }
  fab!(:private_category2) { Fabricate(:private_category, group: group) }

  fab!(:topic_in_public_category) do
    Fabricate(:topic, category: public_category, tags: [tag1, tag2]).tap do |topic|
      Fabricate(:post, topic: topic)
    end
  end

  fab!(:topic_in_private_category) do
    Fabricate(:topic, category: private_category, tags: [tag1, tag2]).tap do |topic|
      Fabricate(:post, topic: topic)
    end
  end

  fab!(:private_message) do
    topic = Fabricate(:private_message_post).topic
    topic.update!(tags: [tag1, tag2])
    topic
  end

  before do
    expect(tag1.public_topic_count).to eq(1)
    expect(tag1.staff_topic_count).to eq(2)
    expect(tag1.pm_topic_count).to eq(1)
    expect(tag2.reload.public_topic_count).to eq(1)
    expect(tag2.staff_topic_count).to eq(2)
    expect(tag2.pm_topic_count).to eq(1)
  end

  it "should decrease Tag#public_topic_count for all tags when topic's category is changed from a public category to a read restricted category" do
    expect { topic_in_public_category.change_category_to_id(private_category.id) }.to change {
      tag1.reload.public_topic_count
    }.by(-1).and change { tag2.reload.public_topic_count }.by(-1)
  end

  it "should increase Tag#public_topic_count for all tags when topic's category is changed from a read restricted category to a public category" do
    expect { topic_in_private_category.change_category_to_id(public_category.id) }.to change {
      tag1.reload.public_topic_count
    }.by(1).and change { tag2.reload.public_topic_count }.by(1)
  end

  it "should not change Tag#public_topic_count for all tags when topic's category is changed from a public category to another public category" do
    expect do
      topic_in_public_category.change_category_to_id(public_category2.id)
    end.to not_change { tag1.reload.public_topic_count }.and not_change {
            tag2.reload.public_topic_count
          }
  end

  it "should not change Tag#public_topic_count for all tags when topic's category is changed from a read restricted category to another read restricted category" do
    expect do
      topic_in_private_category.change_category_to_id(private_category2.id)
    end.to not_change { tag1.reload.public_topic_count }.and not_change {
            tag2.reload.public_topic_count
          }
  end

  it "increases Tag#public_topic_count for all tags when topic is converted from private message to a regular topic in a public category" do
    expect do
      private_message.convert_to_public_topic(
        Discourse.system_user,
        category_id: public_category.id,
      )
    end.to change { tag1.reload.public_topic_count }.by(1).and change {
            tag2.reload.public_topic_count
          }.by(1)
  end

  it "should not change Tag#public_topic_count for all tags when topic is converted from private message to a regular topic in a read restricted category" do
    expect do
      private_message.convert_to_public_topic(
        Discourse.system_user,
        category_id: private_category.id,
      )
    end.to not_change { tag1.reload.public_topic_count }.and not_change {
            tag2.reload.public_topic_count
          }
  end

  it "should decrease Tag#public_topic_count for all tags when regular topic in public category is converted to a private message" do
    expect do
      topic_in_public_category.convert_to_private_message(Discourse.system_user)
    end.to change { tag1.reload.public_topic_count }.by(-1).and change {
            tag2.reload.public_topic_count
          }.by(-1)
  end

  it "should not change Tag#public_topic_count for all tags when regular topic in read restricted category is converted to a private message" do
    expect do
      topic_in_private_category.convert_to_private_message(Discourse.system_user)
    end.to not_change { tag1.reload.public_topic_count }.and not_change {
            tag2.reload.public_topic_count
          }
  end
end
