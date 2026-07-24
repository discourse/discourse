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
      expect(serialized[:topic_view][:accepted_answers][0][:post_number]).to eq(post2.post_number)
    end

    it "returns nil when the topic does not have an accepted answer" do
      unsolved_topic = Fabricate(:topic)
      serializer = TopicViewSerializer.new(TopicView.new(unsolved_topic), scope: Guardian.new(user))
      serialized = serializer.as_json
      expect(serialized[:topic_view][:accepted_answers]).to be_nil
    end

    it "returns nil when the accepted answer post does not exist" do
      weird_topic = Fabricate(:solved_topic)
      Fabricate(:topic_answer, solved_topic: weird_topic)
      weird_topic.topic_answers.first.update!(answer_post_id: 19_238_319)
      serializer =
        TopicViewSerializer.new(TopicView.new(weird_topic.topic), scope: Guardian.new(user))
      serialized = serializer.as_json
      expect(serialized[:topic_view][:accepted_answers]).to be_nil
    end

    describe "with multiple solutions enabled" do
      fab!(:post3) { Fabricate(:post, topic:, user:) }
      fab!(:solved_topic) { Fabricate(:solved_topic, topic:) }
      before do
        SiteSetting.solved_allow_multiple_solutions = true
        Fabricate(:topic_answer, solved_topic:, post: post2)
        Fabricate(:topic_answer, solved_topic:, post: post3)
      end

      it "returns all answer posts when the topic has accepted answers" do
        serializer = TopicViewSerializer.new(TopicView.new(topic), scope: Guardian.new(user))
        serialized = serializer.as_json
        expect(serialized[:topic_view][:accepted_answers].length).to eq(2)
        expect(serialized[:topic_view][:accepted_answers][0][:post_number]).to eq(post2.post_number)
        expect(serialized[:topic_view][:accepted_answers][1][:post_number]).to eq(post3.post_number)
      end
    end
  end

  describe "#has_accepted_answer" do
    it "is true when the topic has an accepted answer" do
      Fabricate(:solved_topic, topic: topic, answer_post: post2)
      serializer = TopicViewSerializer.new(TopicView.new(topic), scope: Guardian.new(user))
      expect(serializer.as_json[:topic_view][:has_accepted_answer]).to eq(true)
    end

    it "is false when the topic has no accepted answer" do
      unsolved_topic = Fabricate(:topic)
      serializer = TopicViewSerializer.new(TopicView.new(unsolved_topic), scope: Guardian.new(user))
      expect(serializer.as_json[:topic_view][:has_accepted_answer]).to eq(false)
    end

    it "is not included when solved is disabled" do
      SiteSetting.solved_enabled = false
      Fabricate(:solved_topic, topic: topic, answer_post: post2)
      serializer = TopicViewSerializer.new(TopicView.new(topic), scope: Guardian.new(user))
      expect(serializer.as_json[:topic_view]).not_to have_key(:has_accepted_answer)
    end
  end
end
