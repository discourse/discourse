# frozen_string_literal: true

require_relative "../../db/migrate/20250318024954_remove_duplicates_from_discourse_solved_solved_topics"

RSpec.describe RemoveDuplicatesFromDiscourseSolvedSolvedTopics, type: :migration do
  let(:migration) { described_class.new }

  before do
    # temp drop unique constraints to allow testing duplicate entries
    ActiveRecord::Base.connection.execute(
      "DROP INDEX IF EXISTS index_discourse_solved_solved_topics_on_topic_id;",
    )
    ActiveRecord::Base.connection.execute(
      "DROP INDEX IF EXISTS index_discourse_solved_solved_topics_on_answer_post_id;",
    )
  end

  after do
    DiscourseSolved::SolvedTopic.delete_all

    # reapply unique indexes
    ActiveRecord::Base.connection.execute(
      "CREATE UNIQUE INDEX index_discourse_solved_solved_topics_on_topic_id ON discourse_solved_solved_topics (topic_id);",
    )
    ActiveRecord::Base.connection.execute(
      "CREATE UNIQUE INDEX index_discourse_solved_solved_topics_on_answer_post_id ON discourse_solved_solved_topics (answer_post_id);",
    )
  end

  describe "removal of duplicate answer_post_ids" do
    it "keeps only the earliest record for each answer_post_id" do
      topic1 = Fabricate(:topic)
      post1 = Fabricate(:post, topic: topic1)
      topic2 = Fabricate(:topic)
      post2 = Fabricate(:post, topic: topic2)

      earlier = Fabricate(:solved_topic, topic: topic1, answer_post: post1, created_at: 2.days.ago)
      Fabricate(:solved_topic, topic: topic1, answer_post: post1, created_at: 1.day.ago)
      Fabricate(:solved_topic, topic: topic1, answer_post: post1, created_at: Date.today)
      another = Fabricate(:solved_topic, topic: topic2, answer_post: post2, created_at: Date.today)

      expect(DiscourseSolved::SolvedTopic.count).to eq(4)
      migration.up

      expect(DiscourseSolved::SolvedTopic.count).to eq(2)
      expect(DiscourseSolved::SolvedTopic.pluck(:id, :answer_post_id)).to contain_exactly(
        [earlier.id, post1.id],
        [another.id, post2.id],
      )
    end
  end
end
