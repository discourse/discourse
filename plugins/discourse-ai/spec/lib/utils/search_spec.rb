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
  end
end
