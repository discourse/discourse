# frozen_string_literal: true

RSpec.describe DiscourseSolved::PostMoverExtension do
  fab!(:admin)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic_with_op, category: category) }
  fab!(:reply) { Fabricate(:post, topic: topic) }
  fab!(:another_reply) { Fabricate(:post, topic: topic) }
  fab!(:destination_topic) { Fabricate(:topic_with_op, category: category) }

  let!(:post_ids) { topic.posts.pluck(:id) }

  before { SiteSetting.allow_solved_on_all_topics = true }

  it "moves the solved topic record to the destination topic" do
    solved = Fabricate(:solved_topic, topic: topic, answer_post: reply)

    topic.move_posts(admin, post_ids, destination_topic_id: destination_topic.id)

    expect(solved.reload.topic_id).to eq(destination_topic.id)
  end

  it "moves the solved topic record when moving the solution post to a new topic" do
    solved = Fabricate(:solved_topic, topic: topic, answer_post: reply)

    topic.move_posts(admin, [reply.id], title: "This is a new topic for the moved post")

    expect(topic.reload.solved).to be_nil
    expect(solved.reload.topic_id).not_to eq(topic.id)
  end

  it "removes the solved topic record when the destination already has a solution" do
    solved = Fabricate(:solved_topic, topic: topic, answer_post: reply)
    Fabricate(:solved_topic, topic: destination_topic, answer_post: destination_topic.first_post)

    topic.move_posts(admin, post_ids, destination_topic_id: destination_topic.id)

    expect(topic.reload.solved).to be_nil
    expect(destination_topic.reload.solved).to be_present
    expect(DiscourseSolved::SolvedTopic.find_by(id: solved.id)).to be_nil
  end

  it "does not update the solved topic record when the answer post is not moved" do
    solved = Fabricate(:solved_topic, topic: topic, answer_post: reply)

    topic.move_posts(admin, [post_ids.first], destination_topic_id: destination_topic.id)

    expect(solved.reload.topic_id).to eq(topic.id)
  end

  it "allows moving posts from a topic without a solution" do
    topic.move_posts(admin, [reply.id], title: "This is a new topic for the moved post")

    expect(topic.reload.solved).to be_nil
  end
end
