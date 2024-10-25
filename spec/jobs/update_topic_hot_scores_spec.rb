# frozen_string_literal: true

require "file_store/s3_store"

RSpec.describe Jobs::UpdateTopicHotScores do
  let(:job) { subject }

  fab!(:topic) { Fabricate(:topic, created_at: 1.day.ago) }

  it "runs an update even if hot is missing from top_menu (once every 6 hours)" do
    SiteSetting.top_menu = "latest"
    job.execute({})

    expect(TopicHotScore.where(topic_id: topic.id).count).to eq(1)

    topic2 = Fabricate(:topic, created_at: 1.hour.ago)
    job.execute({})

    expect(TopicHotScore.where(topic_id: topic2.id).count).to eq(0)
  end

  it "runs an update unconditionally if hot is in top menu" do
    SiteSetting.top_menu = "latest|hot"
    job.execute({})

    expect(TopicHotScore.where(topic_id: topic.id).count).to eq(1)

    topic2 = Fabricate(:topic, created_at: 1.hour.ago)
    job.execute({})

    expect(TopicHotScore.where(topic_id: topic2.id).count).to eq(1)
  end
end
