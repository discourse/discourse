# frozen_string_literal: true

RSpec.describe DiscourseAi::Utils::Search do
  before do
    enable_current_plugin
    SearchIndexer.enable
  end

  after { SearchIndexer.disable }

  fab!(:admin)
  fab!(:user)
  fab!(:group)
  fab!(:parent_category) { Fabricate(:category, name: "animals") }
  fab!(:category) { Fabricate(:category, parent_category: parent_category, name: "amazing-cat") }
  fab!(:tag_funny) { Fabricate(:tag, name: "funny") }
  fab!(:tag_sad) { Fabricate(:tag, name: "sad") }
  fab!(:tag_hidden) { Fabricate(:tag, name: "hidden") }
  fab!(:staff_tag_group) do
    tag_group = Fabricate.build(:tag_group, name: "Staff only", tag_names: ["hidden"])

    tag_group.permissions = [
      [Group::AUTO_GROUPS[:staff], TagGroupPermission.permission_types[:full]],
    ]
    tag_group.save!
    tag_group
  end

  fab!(:topic_with_tags) do
    Fabricate(:topic, category: category, tags: [tag_funny, tag_sad, tag_hidden])
  end

  fab!(:private_category) do
    c = Fabricate(:category_with_definition)
    c.set_permissions(group => :readonly)
    c.save
    c
  end

  describe ".perform_search" do
    it "returns search results with correct format" do
      post = Fabricate(:post, topic: topic_with_tags)

      results =
        described_class.perform_search(
          search_query: post.raw,
          user: post.user.username,
          current_user: admin,
        )

      expect(results).to have_key(:args)
      expect(results).to have_key(:rows)
      expect(results).to have_key(:column_names)
      expect(results[:rows].length).to eq(1)
    end

    it "handles no results" do
      results =
        described_class.perform_search(
          search_query: "NONEXISTENTTERMNOONEWOULDSEARCH",
          current_user: admin,
        )

      expect(results[:rows]).to eq([])
      expect(results[:instruction]).to eq("nothing was found, expand your search")
    end

    it "returns private results when user has access" do
      private_post = Fabricate(:post, topic: Fabricate(:topic, category: private_category))

      # Regular user without access
      results = described_class.perform_search(search_query: private_post.raw, current_user: user)
      expect(results[:rows].length).to eq(0)

      # Add user to group with access
      GroupUser.create!(group: group, user: user)

      # Now should find the private post
      results =
        described_class.perform_search(
          search_query: private_post.raw,
          current_user: user,
          result_style: :detailed,
        )
      expect(results[:rows].length).to eq(1)
      # so API is less confusing
      expect(results.key?(:column_names)).to eq(false)

      results =
        described_class.perform_search(
          search_query: private_post.raw,
          current_user: user,
          result_style: :compact,
        )

      expect(results[:rows].length).to eq(1)
      # so API is less confusing
      expect(results[:column_names]).to be_present
    end

    it "properly handles subfolder URLs" do
      Discourse.stubs(:base_path).returns("/subfolder")

      post = Fabricate(:post, topic: topic_with_tags)

      results = described_class.perform_search(search_query: post.raw, current_user: admin)

      url_index = results[:column_names].index("url")
      expect(results[:rows][0][url_index]).to include("/subfolder")
    end

    it "returns rich topic information" do
      post = Fabricate(:post, like_count: 1, topic: topic_with_tags)
      post.topic.update!(views: 100, posts_count: 2, like_count: 10)

      results = described_class.perform_search(search_query: post.raw, current_user: admin)

      row = results[:rows].first

      category_index = results[:column_names].index("category")
      expect(row[category_index]).to eq("animals > amazing-cat")

      tags_index = results[:column_names].index("tags")
      expect(row[tags_index]).to eq("funny, sad")

      likes_index = results[:column_names].index("likes")
      expect(row[likes_index]).to eq(1)

      topic_likes_index = results[:column_names].index("topic_likes")
      expect(row[topic_likes_index]).to eq(10)

      topic_views_index = results[:column_names].index("topic_views")
      expect(row[topic_views_index]).to eq(100)

      topic_replies_index = results[:column_names].index("topic_replies")
      expect(row[topic_replies_index]).to eq(1)
    end

    context "when using semantic search" do
      let(:query) { "this is an expanded search" }
      after do
        if defined?(DiscourseAi::Embeddings::SemanticSearch)
          DiscourseAi::Embeddings::SemanticSearch.clear_cache_for(query)
        end
      end

      it "includes semantic search results when enabled" do
        assign_fake_provider_to(:ai_default_llm_model)

        vector_def = Fabricate(:embedding_definition)
        SiteSetting.ai_embeddings_selected_model = vector_def.id
        SiteSetting.ai_embeddings_enabled = true
        SiteSetting.ai_embeddings_semantic_search_enabled = true

        hyde_embedding = [0.049382] * vector_def.dimensions
        EmbeddingsGenerationStubs.hugging_face_service(query, hyde_embedding)

        post = Fabricate(:post, topic: topic_with_tags)
        DiscourseAi::Embeddings::Schema.for(Topic).store(post.topic, hyde_embedding, "digest")

        # Using a completely different search query, should still find via semantic search
        results =
          DiscourseAi::Completions::Llm.with_prepared_responses([query]) do
            described_class.perform_search(
              search_query: "totally different query",
              current_user: admin,
            )
          end

        expect(results[:rows].length).to eq(1)
      end

      it "can disable semantic search with hyde parameter" do
        assign_fake_provider_to(:ai_default_llm_model)

        vector_def = Fabricate(:embedding_definition)
        SiteSetting.ai_embeddings_selected_model = vector_def.id
        SiteSetting.ai_embeddings_semantic_search_enabled = true

        embedding = [0.049382] * vector_def.dimensions
        EmbeddingsGenerationStubs.hugging_face_service(query, embedding)

        post = Fabricate(:post, topic: topic_with_tags)
        DiscourseAi::Embeddings::Schema.for(Topic).store(post.topic, embedding, "digest")

        WebMock
          .stub_request(:post, "https://test.com/embeddings")
          .with(body: "{\"inputs\":\"totally different query\",\"truncate\":true}")
          .to_return(status: 200, body: embedding.to_json)

        results =
          described_class.perform_search(
            search_query: "totally different query",
            hyde: false,
            current_user: admin,
          )

        expect(results[:rows].length).to eq(0)
      end
    end

    it "passes all search parameters to the results args" do
      post = Fabricate(:post, topic: topic_with_tags)

      search_params = {
        search_query: post.raw,
        category: category.name,
        user: post.user.username,
        order: "latest",
        max_posts: 10,
        tags: tag_funny.name,
        before: "2030-01-01",
        after: "2000-01-01",
        status: "public",
        max_results: 15,
      }

      results = described_class.perform_search(**search_params, current_user: admin)

      expect(results[:args]).to include(search_params)
    end

    context "with filter-only queries (no search term)" do
      fab!(:topic1) { Fabricate(:topic, category: category, views: 100, like_count: 10) }
      fab!(:topic2) { Fabricate(:topic, category: category, views: 50, like_count: 20) }
      fab!(:topic3) { Fabricate(:topic, tags: [tag_funny]) }
      fab!(:post1) { Fabricate(:post, topic: topic1) }
      fab!(:post2) { Fabricate(:post, topic: topic2) }
      fab!(:post3) { Fabricate(:post, topic: topic3) }

      it "returns topics with order:latest filter only (uses TopicsFilter fallback)" do
        results = described_class.perform_search(order: "latest", current_user: admin)

        expect(results[:rows]).to be_present
        expect(results[:args][:order]).to eq("latest")
      end

      it "returns posts filtered by category with order" do
        results =
          described_class.perform_search(
            category: category.slug,
            order: "views",
            current_user: admin,
          )

        expect(results[:rows]).to be_present

        url_index = results[:column_names].index("url")
        topic_urls = results[:rows].map { |row| row[url_index] }
        expect(topic_urls.join).to include("/t/#{topic1.slug}/#{topic1.id}")
        expect(topic_urls.join).to include("/t/#{topic2.slug}/#{topic2.id}")
        expect(topic_urls.join).not_to include("/t/#{topic3.slug}/#{topic3.id}")
      end

      it "returns posts filtered by tags" do
        results = described_class.perform_search(tags: tag_funny.name, current_user: admin)

        expect(results[:rows]).to be_present

        url_index = results[:column_names].index("url")
        topic_urls = results[:rows].map { |row| row[url_index] }
        expect(topic_urls.join).to include("/t/#{topic3.slug}/#{topic3.id}")
      end

      it "returns posts filtered by user" do
        results = described_class.perform_search(user: post1.user.username, current_user: admin)

        expect(results[:rows]).to be_present
      end

      it "returns empty results when no filters are provided and no search query" do
        results = described_class.perform_search(current_user: admin)

        expect(results[:rows]).to eq([])
      end

      it "respects category permissions in filter-only queries" do
        private_topic = Fabricate(:topic, category: private_category)
        Fabricate(:post, topic: private_topic)

        results = described_class.perform_search(order: "latest", current_user: user)
        url_index = results[:column_names].index("url")
        topic_urls = results[:rows].map { |row| row[url_index] }.join
        expect(topic_urls).not_to include("/t/#{private_topic.slug}/#{private_topic.id}")

        GroupUser.create!(group: group, user: user)
        results = described_class.perform_search(order: "latest", current_user: user)
        url_index = results[:column_names].index("url")
        topic_urls = results[:rows].map { |row| row[url_index] }.join
        expect(topic_urls).to include("/t/#{private_topic.slug}/#{private_topic.id}")
      end

      it "returns correct result structure for filter-only queries with category" do
        results =
          described_class.perform_search(
            category: category.slug,
            order: "latest",
            current_user: admin,
          )

        expect(results).to have_key(:args)
        expect(results).to have_key(:rows)
        expect(results).to have_key(:column_names)
        expect(results[:column_names]).to include("title", "url", "username", "category")
      end

      it "respects max_results for filter-only queries" do
        results =
          described_class.perform_search(
            category: category.slug,
            order: "latest",
            max_results: 1,
            current_user: admin,
          )

        expect(results[:rows].length).to be <= 1
      end

      it "still uses normal search when search_query is provided with filters" do
        unique_content = "uniquesearchterm#{SecureRandom.hex(8)}"
        _searchable_post = Fabricate(:post, raw: unique_content, topic: topic1)

        results =
          described_class.perform_search(
            search_query: unique_content,
            category: category.slug,
            order: "latest",
            current_user: admin,
          )

        expect(results[:rows]).to be_present
        expect(results[:args][:search_query]).to eq(unique_content)
      end
    end
  end

  describe ".order_to_filter_syntax" do
    it "maps AI search order values to TopicsFilter syntax" do
      expect(described_class.order_to_filter_syntax("latest")).to eq("order:activity")
      expect(described_class.order_to_filter_syntax("latest_topic")).to eq("order:activity")
      expect(described_class.order_to_filter_syntax("oldest")).to eq("order:created-asc")
      expect(described_class.order_to_filter_syntax("views")).to eq("order:views")
      expect(described_class.order_to_filter_syntax("likes")).to eq("order:likes")
    end

    it "returns nil for unknown orders" do
      expect(described_class.order_to_filter_syntax("unknown")).to be_nil
      expect(described_class.order_to_filter_syntax(nil)).to be_nil
    end
  end
end
