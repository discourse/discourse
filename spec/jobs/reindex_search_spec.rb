# frozen_string_literal: true

RSpec.describe Jobs::ReindexSearch do
  subject(:job) { described_class.new }

  let(:locale) { "fr" }

  before do
    SearchIndexer.enable
    Jobs.run_immediately!
  end

  # This works since test db has a small record less than limit.
  # Didn't check `topic` because topic doesn't have posts in fabrication
  # thus no search data
  %w[post category user].each do |m|
    it "should rebuild `#{m}` when default_locale changed" do
      SiteSetting.default_locale = "en"
      model = Fabricate(m.to_sym)
      SiteSetting.default_locale = locale
      job.execute({})
      expect(model.public_send("#{m}_search_data").locale).to eq locale
    end

    it "should rebuild `#{m}` when INDEX_VERSION changed" do
      model = Fabricate(m.to_sym)
      # so that search data can be reindexed
      search_data = model.public_send("#{m}_search_data")
      search_data.update!(version: 0)
      model.reload

      job.execute({})
      expect(model.public_send("#{m}_search_data").version).to eq(
        "SearchIndexer::#{m.upcase}_INDEX_VERSION".constantize,
      )
    end
  end

  describe "rebuild_posts" do
    class FakeIndexer
      def self.index(post, force:)
        get_posts.push(post)
      end

      def self.posts
        get_posts
      end

      def self.reset
        get_posts.clear
      end

      private

      def self.get_posts
        @posts ||= []
      end
    end

    after { FakeIndexer.reset }

    it "should not reindex posts that belong to a deleted topic or have been trashed" do
      post = Fabricate(:post)
      post2 = Fabricate(:post)
      post3 = Fabricate(:post)
      PostSearchData.delete_all
      post2.topic.trash!
      post3.trash!

      job.rebuild_posts(indexer: FakeIndexer)

      expect(FakeIndexer.posts).to contain_exactly(post)
    end

    it "should not reindex posts with a developmental version" do
      Fabricate(:post, version: SearchIndexer::POST_INDEX_VERSION + 1)

      job.rebuild_posts(indexer: FakeIndexer)

      expect(FakeIndexer.posts).to eq([])
    end

    it "should not reindex posts with empty raw" do
      post = Fabricate(:post)
      post.post_search_data.destroy!

      post2 = Fabricate.build(:post, raw: "", post_type: Post.types[:small_action])

      post2.save!(validate: false)

      job.rebuild_posts(indexer: FakeIndexer)

      expect(FakeIndexer.posts).to contain_exactly(post)
    end
  end

  describe "rebuild_registered_search_handlers" do
    let(:plugin) { Plugin::Instance.new }
    let(:mock_model_class) do
      Class.new do
        def self.name
          "TestModel"
        end

        def self.table_name
          "test_models"
        end

        def self.find_by(id:)
          return nil unless id == 1
          new(id: id)
        end

        def initialize(id:)
          @id = id
        end

        attr_reader :id
      end
    end

    let(:mock_search_data_class) { double }

    after { DiscoursePluginRegistry.reset! }

    it "rebuilds records for registered search handlers" do
      indexer = mock("SearchIndexer")
      indexer.expects(:index).once

      plugin.register_search_index(
        model_class: mock_model_class,
        search_data_class: mock_search_data_class,
        index_version: 1,
        search_data: ->(record, indexer_helper) { { a_weight: "test" } },
        load_unindexed_record_ids: ->(**_args) { [1] },
      )

      job.rebuild_registered_search_handlers(indexer: indexer)
    end

    it "skips disabled handlers" do
      indexer = mock("SearchIndexer")
      indexer.expects(:index).never

      plugin.register_search_index(
        model_class: mock_model_class,
        search_data_class: mock_search_data_class,
        index_version: 1,
        search_data: ->(record, indexer_helper) { { a_weight: "test" } },
        load_unindexed_record_ids: ->(**_args) { [1] },
        enabled: -> { false },
      )

      job.rebuild_registered_search_handlers(indexer: indexer)
    end

    it "passes limit and index_version to load_unindexed_record_ids" do
      indexer = mock("SearchIndexer")
      received_args = nil

      plugin.register_search_index(
        model_class: mock_model_class,
        search_data_class: mock_search_data_class,
        index_version: 2,
        search_data: ->(record, indexer_helper) { { a_weight: "test" } },
        load_unindexed_record_ids:
          lambda do |**args|
            received_args = args
            []
          end,
      )

      job.rebuild_registered_search_handlers(limit: 5000, indexer: indexer)

      expect(received_args[:limit]).to eq(5000)
      expect(received_args[:index_version]).to eq(2)
    end

    it "handles missing records gracefully" do
      indexer = mock("SearchIndexer")
      indexer.expects(:index).never

      plugin.register_search_index(
        model_class: mock_model_class,
        search_data_class: mock_search_data_class,
        index_version: 1,
        search_data: ->(record, indexer_helper) { { a_weight: "test" } },
        load_unindexed_record_ids: ->(**_args) { [999] },
      )

      expect { job.rebuild_registered_search_handlers(indexer: indexer) }.not_to raise_error
    end
  end

  describe "#execute" do
    it "should clean up topic_search_data of trashed topics" do
      topic = Fabricate(:post).topic
      topic2 = Fabricate(:post).topic

      [topic, topic2].each { |t| SearchIndexer.index(t, force: true) }

      freeze_time(1.day.ago) { topic.trash! }

      expect { job.execute({}) }.to change { TopicSearchData.count }.by(-1)
      expect(Topic.pluck(:id)).to contain_exactly(topic2.id)

      expect(TopicSearchData.pluck(:topic_id)).to contain_exactly(topic2.topic_search_data.topic_id)
    end

    it "should clean up post_search_data of posts with empty raw or posts from trashed topics" do
      post = Fabricate(:post)
      post2 = Fabricate(:post, post_type: Post.types[:small_action])
      post2.raw = ""
      post2.save!(validate: false)
      post3 = Fabricate(:post)
      post3.topic.trash!
      post4, post5, post6 = nil

      freeze_time(1.day.ago) do
        post4 = Fabricate(:post)
        post4.topic.trash!

        post5 = Fabricate(:post)
        post6 = Fabricate(:post, topic_id: post5.topic_id)
        post6.trash!
      end

      expect { job.execute({}) }.to change { PostSearchData.count }.by(-3)

      expect(Post.pluck(:id)).to contain_exactly(post.id, post2.id, post3.id, post4.id, post5.id)

      expect(PostSearchData.pluck(:post_id)).to contain_exactly(post.id, post3.id, post5.id)
    end
  end
end
