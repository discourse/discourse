# frozen_string_literal: true

RSpec.describe Jobs::CreateRecentPostSearchIndexes do
  subject { described_class.new }

  fab!(:post) do
    SearchIndexer.enable
    Fabricate(:post)
  end

  fab!(:post_2) do
    SearchIndexer.enable
    Fabricate(:post)
  end

  before { SearchIndexer.enable }

  describe "#execute" do
    it "should not create the index if requried posts size has not been reached" do
      SiteSetting.search_recent_posts_size = 1
      SiteSetting.search_enable_recent_regular_posts_offset_size = 3

      expect do subject.execute({}) end.to_not change {
        SiteSetting.search_recent_regular_posts_offset_post_id
      }
    end

    it "should create the right index" do
      SiteSetting.search_recent_posts_size = 1
      SiteSetting.search_enable_recent_regular_posts_offset_size = 1

      subject.execute({})

      expect(SiteSetting.search_recent_regular_posts_offset_post_id).to eq(post_2.id)

      expect(DB.query_single(<<~SQL).first).to eq(1)
      SELECT 1 FROM pg_indexes WHERE indexname = '#{described_class::REGULAR_POST_SEARCH_DATA_INDEX_NAME}'
      SQL
    end
  end
end
