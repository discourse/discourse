# frozen_string_literal: true

RSpec.describe DiscourseSolved::PostMoverExtension do
  fab!(:admin)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic_with_op, category: category) }
  fab!(:reply) { Fabricate(:post, topic: topic) }
  fab!(:destination_topic) { Fabricate(:topic_with_op, category: category) }

  let!(:solved) { Fabricate(:solved_topic, topic: topic, answer_post: reply) }
  let!(:post_ids) { topic.posts.pluck(:id) }

  before { SiteSetting.allow_solved_on_all_topics = true }

  it "updates the solved topic record to point to the destination topic" do
    topic.move_posts(admin, post_ids, destination_topic_id: destination_topic.id)

    expect(solved.reload.topic_id).to eq(destination_topic.id)
  end

  it "removes the solved topic record when the destination already has a solution" do
    Fabricate(:solved_topic, topic: destination_topic, answer_post: destination_topic.first_post)

    topic.move_posts(admin, post_ids, destination_topic_id: destination_topic.id)

    expect(topic.reload.solved).to be_nil
    expect(destination_topic.reload.solved).to be_present
  end

  it "does not update the solved topic record when the answer post is not moved" do
    topic.move_posts(admin, [post_ids.first], destination_topic_id: destination_topic.id)

    expect(solved.reload.topic_id).to eq(topic.id)
  end
end
