# frozen_string_literal: true

require_relative "../../db/migrate/20250318024953_copy_solved_topic_custom_field_to_discourse_solved_solved_topics"

RSpec.describe CopySolvedTopicCustomFieldToDiscourseSolvedSolvedTopics, type: :migration do
  let(:migration) { described_class.new }

  describe "handling duplicates" do
    it "ensures only unique topic_id and answer_post_id are inserted" do
      topic = Fabricate(:topic)
      topic1 = Fabricate(:topic)
      post1 = Fabricate(:post, topic: topic)
      TopicCustomField.create!(
        topic_id: topic.id,
        name: "accepted_answer_post_id",
        value: post1.id.to_s,
      )
      # explicit duplicate
      TopicCustomField.create!(
        topic_id: topic1.id,
        name: "accepted_answer_post_id",
        value: post1.id.to_s,
      )

      second_topic = Fabricate(:topic)
      post2 = Fabricate(:post, topic: second_topic)
      TopicCustomField.create!(
        topic_id: second_topic.id,
        name: "accepted_answer_post_id",
        value: post2.id.to_s,
      )

      migration.up
      expected_count = DiscourseSolved::SolvedTopic.count

      expect(expected_count).to eq(2)

      expect(DiscourseSolved::SolvedTopic.where(topic_id: topic.id).count).to eq(1)
      expect(DiscourseSolved::SolvedTopic.where(answer_post_id: post1.id).count).to eq(1)
    end
  end
end
