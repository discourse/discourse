# frozen_string_literal: true

RSpec.describe Search do
  fab!(:topic) { Fabricate(:topic) }
  fab!(:topic2) { Fabricate(:topic) }
  fab!(:regular_post) { Fabricate(:post, topic: topic, raw: <<~RAW) }
      Somewhere over the rainbow but no poll.
    RAW

  fab!(:post_with_poll) { Fabricate(:post, topic: topic2, raw: <<~RAW) }
      Somewhere over the rainbow with a poll.
      [poll]
      * Like
      * Dislike
      [/poll]
    RAW

  before do
    SearchIndexer.enable
    Jobs.run_immediately!

    SearchIndexer.index(topic2, force: true)
    SearchIndexer.index(topic, force: true)
  end

  after do
    SiteSetting.poll_enabled = true
    SearchIndexer.disable
  end

  describe "in:polls" do
    it "allows filtering search to posts containing polls" do
      results = Search.execute("rainbow in:polls", guardian: Guardian.new())
      expect(results.posts).to contain_exactly(post_with_poll)
    end

    it "ignores in:polls if plugin is disabled" do
      SiteSetting.poll_enabled = false
      results = Search.execute("rainbow in:polls", guardian: Guardian.new())
      expect(results.posts).to contain_exactly(regular_post, post_with_poll)
    end
  end
end