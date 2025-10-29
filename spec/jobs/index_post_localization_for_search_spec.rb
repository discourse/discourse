# frozen_string_literal: true

RSpec.describe Jobs::IndexPostLocalizationForSearch do
  subject(:job) { described_class.new }

  fab!(:post)

  before { SiteSetting.content_localization_enabled = true }

  it "indexes post localizations when job is executed" do
    allow(SearchIndexer).to receive(:index_post_localizations)
    job.execute(post_id: post.id)
    expect(SearchIndexer).to have_received(:index_post_localizations).with(post)
  end

  it "does nothing if post_id is blank" do
    allow(SearchIndexer).to receive(:index_post_localizations)
    job.execute(post_id: nil)
    expect(SearchIndexer).not_to have_received(:index_post_localizations)
  end

  it "does nothing if post does not exist" do
    allow(SearchIndexer).to receive(:index_post_localizations)
    job.execute(post_id: 999_999)
    expect(SearchIndexer).not_to have_received(:index_post_localizations)
  end
end
