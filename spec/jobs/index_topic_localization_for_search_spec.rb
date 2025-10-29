# frozen_string_literal: true

RSpec.describe Jobs::IndexTopicLocalizationForSearch do
  subject(:job) { described_class.new }

  fab!(:topic)

  before { SiteSetting.content_localization_enabled = true }

  it "indexes topic localizations when job is executed" do
    allow(SearchIndexer).to receive(:index_topic_localizations)
    job.execute(topic_id: topic.id)
    expect(SearchIndexer).to have_received(:index_topic_localizations).with(topic)
  end

  it "does nothing if topic_id is blank" do
    allow(SearchIndexer).to receive(:index_topic_localizations)
    job.execute(topic_id: nil)
    expect(SearchIndexer).not_to have_received(:index_topic_localizations)
  end

  it "does nothing if topic does not exist" do
    allow(SearchIndexer).to receive(:index_topic_localizations)
    job.execute(topic_id: 999_999)
    expect(SearchIndexer).not_to have_received(:index_topic_localizations)
  end
end
