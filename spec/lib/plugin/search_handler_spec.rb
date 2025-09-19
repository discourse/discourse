# frozen_string_literal: true

RSpec.describe Plugin::Instance do
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
        new(id: id)
      end

      def initialize(id:)
        @id = id
      end

      attr_reader :id

      def message
        "test message #{@id}"
      end

      def cooked
        "<p>test cooked content #{@id}</p>"
      end
    end
  end

  let(:mock_search_data_class) do
    Class.new do
      def self.upsert(params)
        @last_params = params
      end

      def self.last_params
        @last_params
      end
    end
  end

  before do
    @original_search_handlers = DiscoursePluginRegistry._raw_search_handlers.dup
    DiscoursePluginRegistry._raw_search_handlers.clear
  end

  after do
    DiscoursePluginRegistry._raw_search_handlers.clear
    DiscoursePluginRegistry._raw_search_handlers.concat(@original_search_handlers)
  end

  describe "#register_search_index" do
    it "registers a search index with all required parameters" do
      plugin.register_search_index(
        model_class: mock_model_class,
        search_data_class: mock_search_data_class,
        index_version: 1,
        search_data:
          proc do |obj, indexer_helper|
            { a_weight: obj.message, d_weight: indexer_helper.scrub_html(obj.cooked)[0..100] }
          end,
        load_unindexed_record_ids: proc { |limit:, index_version:| [1, 2, 3].take(limit) },
      )

      expect(DiscoursePluginRegistry.search_handlers.length).to eq(1)

      handler = DiscoursePluginRegistry.search_handlers.first
      expect(handler[:table_name]).to eq("test_model")
      expect(handler[:model_class]).to eq(mock_model_class)
      expect(handler[:search_data_class]).to eq(mock_search_data_class)
      expect(handler[:index_version]).to eq(1)
      expect(handler[:search_data]).to be_a(Proc)
      expect(handler[:load_unindexed_record_ids]).to be_a(Proc)
    end

    it "allows the search_data proc to extract data from objects" do
      plugin.register_search_index(
        model_class: mock_model_class,
        search_data_class: mock_search_data_class,
        index_version: 1,
        search_data:
          proc do |obj, indexer_helper|
            { a_weight: obj.message, d_weight: indexer_helper.scrub_html(obj.cooked) }
          end,
        load_unindexed_record_ids: proc { |limit:, index_version:| [] },
      )

      handler = DiscoursePluginRegistry.search_handlers.first
      test_obj = mock_model_class.new(id: 123)
      indexer_helper = SearchIndexer::IndexerHelper.new

      result = handler[:search_data].call(test_obj, indexer_helper)

      expect(result[:a_weight]).to eq("test message 123")
      expect(result[:d_weight]).to eq("test cooked content 123")
    end

    it "allows the load_unindexed_record_ids proc to return IDs" do
      plugin.register_search_index(
        model_class: mock_model_class,
        search_data_class: mock_search_data_class,
        index_version: 2,
        search_data: proc { |obj, helper| {} },
        load_unindexed_record_ids:
          proc do |limit:, index_version:|
            expect(limit).to be_a(Integer)
            expect(index_version).to eq(2)
            [1, 2, 3, 4, 5].take(limit)
          end,
      )

      handler = DiscoursePluginRegistry.search_handlers.first
      result = handler[:load_unindexed_record_ids].call(limit: 3, index_version: 2)

      expect(result).to eq([1, 2, 3])
    end
  end

  describe "SearchIndexer integration" do
    before do
      SearchIndexer.enable
      plugin.register_search_index(
        model_class: mock_model_class,
        search_data_class: mock_search_data_class,
        index_version: 1,
        search_data:
          proc do |obj, indexer_helper|
            { a_weight: obj.message, d_weight: indexer_helper.scrub_html(obj.cooked) }
          end,
        load_unindexed_record_ids: proc { |limit:, index_version:| [] },
      )
    end

    after { SearchIndexer.disable }

    it "uses registered index when indexing objects" do
      test_obj = mock_model_class.new(id: 123)

      expect(mock_search_data_class).to receive(:upsert) do |params|
        expect(params["test_model_id"]).to eq(123)
        expect(params["version"]).to eq(1)
        expect(params["locale"]).to eq(SiteSetting.default_locale)
        expect(params["raw_data"]).to include("test message")
      end

      SearchIndexer.index(test_obj)
    end

    it "falls back to default behavior for unregistered models" do
      unregistered_obj = Object.new

      # Should not raise an error and should not call our mock
      expect(mock_search_data_class).not_to receive(:upsert)
      expect { SearchIndexer.index(unregistered_obj) }.not_to raise_error
    end
  end

  describe "IndexerHelper" do
    let(:indexer_helper) { SearchIndexer::IndexerHelper.new }

    it "provides scrub_html method" do
      html = "<p>Hello <script>alert('xss')</script> World</p>"
      result = indexer_helper.scrub_html(html)

      expect(result).to be_a(String)
      expect(result).to include("Hello")
      expect(result).to include("World")
      expect(result).not_to include("<script>")
    end
  end
end
