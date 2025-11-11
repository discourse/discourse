# frozen_string_literal: true

describe TopicViewSerializer do
  fab!(:topic)
  fab!(:post1) { Fabricate(:post, topic:) }
  fab!(:post2) { Fabricate(:post, topic:) }
  fab!(:user)

  before { SiteSetting.solved_enabled = true }

  describe "#accepted_answer" do
    it "returns the accepted answer post when the topic has an accepted answer" do
      Fabricate(:solved_topic, topic: topic, answer_post: post2)
      serializer = TopicViewSerializer.new(TopicView.new(topic), scope: Guardian.new(user))
      serialized = serializer.as_json
      expect(serialized[:topic_view][:accepted_answer][:post_number]).to eq(post2.post_number)
    end

    it "returns nil when the topic does not have an accepted answer" do
      unsolved_topic = Fabricate(:topic)
      serializer = TopicViewSerializer.new(TopicView.new(unsolved_topic), scope: Guardian.new(user))
      serialized = serializer.as_json
      expect(serialized[:accepted_answer]).to be_nil
    end

    it "returns nil when the accepted answer post does not exist" do
      weird_topic = Fabricate(:solved_topic)
      weird_topic.update!(answer_post_id: 19_238_319)
      serializer =
        TopicViewSerializer.new(TopicView.new(weird_topic.topic), scope: Guardian.new(user))
      serialized = serializer.as_json
      expect(serialized[:accepted_answer]).to be_nil
    end
  end
end
