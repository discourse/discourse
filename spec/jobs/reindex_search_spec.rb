# frozen_string_literal: true

require 'rails_helper'

describe Jobs::ReindexSearch do
  before { SearchIndexer.enable }
  after { SearchIndexer.disable }

  let(:locale) { 'fr' }
  # This works since test db has a small record less than limit.
  # Didn't check `topic` because topic doesn't have posts in fabrication
  # thus no search data
  %w(post category user).each do |m|
    it "should rebuild `#{m}` when default_locale changed" do
      SiteSetting.default_locale = 'en'
      model = Fabricate(m.to_sym)
      SiteSetting.default_locale = locale
      subject.execute({})
      expect(model.public_send("#{m}_search_data").locale).to eq locale
    end

    it "should rebuild `#{m}` when INDEX_VERSION changed" do
      model = Fabricate(m.to_sym)
      # so that search data can be reindexed
      search_data = model.public_send("#{m}_search_data")
      search_data.update!(version: 0)
      model.reload

      subject.execute({})
      expect(model.public_send("#{m}_search_data").version)
        .to eq(SearchIndexer::INDEX_VERSION)
    end
  end

  describe 'rebuild_problem_posts' do
    class FakeIndexer
      def self.index(post, force:)
        @posts ||= []
        @posts.push(post)
      end

      def self.posts
        @posts
      end

      def self.reset
        @posts.clear
      end
    end

    after do
      FakeIndexer.reset
    end

    it (
      'should not reindex posts that belong to a deleted topic ' \
      'or have been trashed'
    ) do
      post = Fabricate(:post)
      post2 = Fabricate(:post)
      post3 = Fabricate(:post)
      PostSearchData.delete_all
      post2.topic.trash!
      post3.trash!

      subject.rebuild_problem_posts(indexer: FakeIndexer)

      expect(FakeIndexer.posts).to contain_exactly(post)
    end

    it 'should not reindex posts with empty raw' do
      post = Fabricate(:post)
      post.post_search_data.destroy!

      post2 = Fabricate.build(:post,
        raw: "",
        post_type: Post.types[:small_action]
      )

      post2.save!(validate: false)

      subject.rebuild_problem_posts(indexer: FakeIndexer)

      expect(FakeIndexer.posts).to contain_exactly(post)
    end
  end

  describe '#execute' do
    it "should clean up topic_search_data of trashed topics" do
      topic = Fabricate(:post).topic
      topic2 = Fabricate(:post).topic

      [topic, topic2].each { |t| SearchIndexer.index(t, force: true) }

      freeze_time(described_class::CLEANUP_GRACE_PERIOD) do
        topic.trash!
      end

      expect { subject.execute({}) }.to change { TopicSearchData.count }.by(-1)
      expect(Topic.pluck(:id)).to contain_exactly(topic2.id)

      expect(TopicSearchData.pluck(:topic_id)).to contain_exactly(
        topic2.topic_search_data.topic_id
      )
    end

    it(
      "should clean up post_search_data of posts with empty raw or posts from " \
      "trashed topics"
    ) do

      post = Fabricate(:post)
      post2 = Fabricate(:post, post_type: Post.types[:small_action])
      post2.raw = ""
      post2.save!(validate: false)
      post3 = Fabricate(:post)
      post3.topic.trash!
      post4, post5, post6 = nil

      freeze_time(described_class::CLEANUP_GRACE_PERIOD) do
        post4 = Fabricate(:post)
        post4.topic.trash!

        post5 = Fabricate(:post)
        post6 = Fabricate(:post, topic_id: post5.topic_id)
        post6.trash!
      end

      expect { subject.execute({}) }.to change { PostSearchData.count }.by(-3)

      expect(Post.pluck(:id)).to contain_exactly(
        post.id, post2.id, post3.id, post4.id, post5.id
      )

      expect(PostSearchData.pluck(:post_id)).to contain_exactly(
        post.id, post3.id, post5.id
      )
    end
  end
end
