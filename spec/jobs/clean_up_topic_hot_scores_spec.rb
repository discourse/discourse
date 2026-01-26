# frozen_string_literal: true

RSpec.describe Jobs::CleanUpTopicHotScores do
  subject(:job) { described_class.new }

  it "deletes hot scores for unlisted topics created within the last month" do
    freeze_time

    unlisted_topic = Fabricate(:topic, visible: false, created_at: 2.weeks.ago)
    TopicHotScore.create!(topic_id: unlisted_topic.id, score: 0.0)

    job.execute({})

    expect(TopicHotScore.find_by(topic_id: unlisted_topic.id)).to be_nil
  end

  it "preserves hot scores for unlisted topics older than 1 month" do
    freeze_time

    old_unlisted = Fabricate(:topic, visible: false, created_at: 2.months.ago)
    TopicHotScore.create!(topic_id: old_unlisted.id, score: 0.0)

    job.execute({})

    expect(TopicHotScore.find_by(topic_id: old_unlisted.id)).to be_present
  end

  it "preserves hot scores for visible topics" do
    freeze_time

    visible_topic = Fabricate(:topic, visible: true, created_at: 2.weeks.ago)
    TopicHotScore.create!(topic_id: visible_topic.id, score: 1.0)

    job.execute({})

    expect(TopicHotScore.find_by(topic_id: visible_topic.id)).to be_present
  end
end
