# frozen_string_literal: true

describe DiscourseAi::Embeddings::EmbeddingsController do
  context "when performing a topic search" do
    fab!(:vector_def, :open_ai_embedding_def)

    before do
      enable_current_plugin
      SiteSetting.min_search_term_length = 3
      SiteSetting.ai_embeddings_selected_model = vector_def.id
      DiscourseAi::Embeddings::SemanticSearch.clear_cache_for("test")
      SearchIndexer.enable
    end

    fab!(:category)
    fab!(:subcategory) { Fabricate(:category, parent_category_id: category.id) }

    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic: topic) }

    fab!(:topic_in_subcategory) { Fabricate(:topic, category: subcategory) }
    fab!(:post_in_subcategory) { Fabricate(:post, topic: topic_in_subcategory) }

    def index(topic)
      vector = DiscourseAi::Embeddings::Vector.instance

      stub_request(:post, "https://api.openai.com/v1/embeddings").to_return(
        status: 200,
        body: JSON.dump({ data: [{ embedding: [0.1] * 1536 }] }),
      )

      vector.generate_representation_from(topic)
    end

    def stub_embedding(query)
      embedding = [0.049382] * 1536

      EmbeddingsGenerationStubs.openai_service(
        vector_def.lookup_custom_param("model_name"),
        query,
        embedding,
      )
    end

    def create_api_key(user)
      key = ApiKey.create!(user: user)
      ApiKeyScope.create!(resource: "discourse_ai", action: "search", api_key_id: key.id)
      key
    end

    it "is able to make API requests using a scoped API key" do
      index(topic)
      query = "test"
      stub_embedding(query)
      user = topic.user

      api_key = create_api_key(user)

      get "/discourse-ai/embeddings/semantic-search.json?q=#{query}&hyde=false",
          headers: {
            "Api-Key" => api_key.key,
            "Api-Username" => user.username,
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["topics"].map { |t| t["id"] }).to contain_exactly(topic.id)
    end

    context "when rate limiting is enabled" do
      before { RateLimiter.enable }

      it "will rate limit correctly" do
        stub_const(described_class, :MAX_HYDE_SEARCHES_PER_MINUTE, 1) do
          stub_const(described_class, :MAX_SEARCHES_PER_MINUTE, 2) do
            query = "test #{SecureRandom.hex}"
            stub_embedding(query)
            get "/discourse-ai/embeddings/semantic-search.json?q=#{query}&hyde=false"
            expect(response.status).to eq(200)

            query = "test #{SecureRandom.hex}"
            stub_embedding(query)
            get "/discourse-ai/embeddings/semantic-search.json?q=#{query}&hyde=false"
            expect(response.status).to eq(200)

            query = "test #{SecureRandom.hex}"
            stub_embedding(query)
            get "/discourse-ai/embeddings/semantic-search.json?q=#{query}&hyde=false"
            expect(response.status).to eq(429)
          end
        end
      end
    end

    it "returns results correctly when performing a non Hyde search" do
      index(topic)
      index(topic_in_subcategory)

      query = "test"
      stub_embedding(query)

      get "/discourse-ai/embeddings/semantic-search.json?q=#{query}&hyde=false"

      expect(response.status).to eq(200)
      expect(response.parsed_body["topics"].map { |t| t["id"] }).to contain_exactly(
        topic.id,
        topic_in_subcategory.id,
      )
    end

    it "is able to filter to a specific category (including sub categories)" do
      index(topic)
      index(topic_in_subcategory)

      query = "test category:#{category.slug}"
      stub_embedding("test")

      get "/discourse-ai/embeddings/semantic-search.json?q=#{query}&hyde=false"

      expect(response.status).to eq(200)
      expect(response.parsed_body["topics"].map { |t| t["id"] }).to eq([topic_in_subcategory.id])
    end

    it "doesn't skip HyDE if the hyde param is missing" do
      assign_fake_provider_to(:ai_default_llm_model)
      index(topic)
      index(topic_in_subcategory)

      query = "test category:#{category.slug}"
      stub_embedding("test")

      DiscourseAi::Completions::Llm.with_prepared_responses(["Hyde #{query}"]) do
        get "/discourse-ai/embeddings/semantic-search.json?q=#{query}"

        expect(response.status).to eq(200)
        expect(response.parsed_body["topics"].map { |t| t["id"] }).to eq([topic_in_subcategory.id])
      end
    end

    context "with HYDE site setting" do
      before do
        assign_fake_provider_to(:ai_default_llm_model)
        index(topic)
        index(topic_in_subcategory)
      end

      it "uses HYDE when site setting is enabled and no hyde param is provided" do
        SiteSetting.ai_embeddings_semantic_search_use_hyde = true

        query = "test"
        stub_embedding("test")

        DiscourseAi::Completions::Llm.with_prepared_responses(["Hyde #{query}"]) do
          get "/discourse-ai/embeddings/semantic-search.json?q=#{query}"

          expect(response.status).to eq(200)
        end
      end

      it "doesn't use HYDE when site setting is disabled and no hyde param is provided" do
        SiteSetting.ai_embeddings_semantic_search_use_hyde = false

        query = "test"
        stub_embedding("test")

        get "/discourse-ai/embeddings/semantic-search.json?q=#{query}"

        expect(response.status).to eq(200)
      end

      it "overrides site setting when hyde=true param is provided" do
        SiteSetting.ai_embeddings_semantic_search_use_hyde = false

        query = "test"
        stub_embedding("test")

        DiscourseAi::Completions::Llm.with_prepared_responses(["Hyde #{query}"]) do
          get "/discourse-ai/embeddings/semantic-search.json?q=#{query}&hyde=true"

          expect(response.status).to eq(200)
        end
      end

      it "overrides site setting when hyde=false param is provided" do
        SiteSetting.ai_embeddings_semantic_search_use_hyde = true

        query = "test"
        stub_embedding("test")

        get "/discourse-ai/embeddings/semantic-search.json?q=#{query}&hyde=false"

        expect(response.status).to eq(200)
      end

      it "handles hyde=0 as false" do
        SiteSetting.ai_embeddings_semantic_search_use_hyde = true

        query = "test"
        stub_embedding("test")

        get "/discourse-ai/embeddings/semantic-search.json?q=#{query}&hyde=0"

        expect(response.status).to eq(200)
      end

      it "handles hyde=1 as true" do
        SiteSetting.ai_embeddings_semantic_search_use_hyde = false

        query = "test"
        stub_embedding("test")

        DiscourseAi::Completions::Llm.with_prepared_responses(["Hyde #{query}"]) do
          get "/discourse-ai/embeddings/semantic-search.json?q=#{query}&hyde=1"

          expect(response.status).to eq(200)
        end
      end
    end
  end

  context "when embedding API fails" do
    fab!(:vector_def, :open_ai_embedding_def)
    fab!(:user)

    before do
      enable_current_plugin
      SiteSetting.min_search_term_length = 3
      SiteSetting.ai_embeddings_selected_model = vector_def.id
      DiscourseAi::Embeddings::SemanticSearch.clear_cache_for("test")
      sign_in(user)
    end

    it "returns empty results instead of 500 error for semantic search" do
      stub_request(:post, "https://api.openai.com/v1/embeddings").to_return(
        status: 429,
        body: JSON.dump({ error: { message: "You exceeded your current quota" } }),
      )

      get "/discourse-ai/embeddings/semantic-search.json?q=test&hyde=false"

      expect(response.status).to eq(200)
      expect(response.parsed_body["topics"]).to be_blank
    end

    it "returns empty results instead of 500 error for quick search" do
      SiteSetting.ai_embeddings_semantic_quick_search_enabled = true

      stub_request(:post, "https://api.openai.com/v1/embeddings").to_return(
        status: 429,
        body: JSON.dump({ error: { message: "You exceeded your current quota" } }),
      )

      get "/discourse-ai/embeddings/quick-search.json?q=test"

      expect(response.status).to eq(200)
      expect(response.parsed_body["topics"]).to be_blank
    end
  end

  context "when performing a quick search" do
    fab!(:vector_def, :open_ai_embedding_def)
    fab!(:user)

    before do
      enable_current_plugin
      SiteSetting.min_search_term_length = 3
      SiteSetting.ai_embeddings_selected_model = vector_def.id
      SiteSetting.ai_embeddings_semantic_quick_search_enabled = true
      DiscourseAi::Embeddings::SemanticSearch.clear_cache_for("test")
      SearchIndexer.enable
      sign_in(user)
    end

    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic: topic, raw: "This is a test post") }

    def index(topic)
      vector = DiscourseAi::Embeddings::Vector.instance

      stub_request(:post, "https://api.openai.com/v1/embeddings").to_return(
        status: 200,
        body: JSON.dump({ data: [{ embedding: [0.1] * 1536 }] }),
      )

      vector.generate_representation_from(topic)
    end

    def stub_embedding(query)
      embedding = [0.049382] * 1536

      EmbeddingsGenerationStubs.openai_service(
        vector_def.lookup_custom_param("model_name"),
        query,
        embedding,
      )
    end

    it "returns 400 when query is too short" do
      get "/discourse-ai/embeddings/quick-search.json?q=ab"

      expect(response.status).to eq(400)
    end

    it "returns results successfully with valid query" do
      index(topic)
      stub_embedding("test")

      get "/discourse-ai/embeddings/quick-search.json?q=test"

      expect(response.status).to eq(200)
      expect(response.parsed_body["posts"]).to be_present
      expect(response.parsed_body["topics"].map { |t| t["id"] }).to contain_exactly(topic.id)
    end

    context "when rate limiting is enabled" do
      before { RateLimiter.enable }

      it "rate limits non-cached queries" do
        61.times do |i|
          query = "test#{i}"
          stub_embedding(query)
          get "/discourse-ai/embeddings/quick-search.json?q=#{query}"
        end

        expect(response.status).to eq(429)
      end

      it "does not rate limit cached queries" do
        query = "cached_query"
        semantic_search = instance_double(DiscourseAi::Embeddings::SemanticSearch)
        allow(DiscourseAi::Embeddings::SemanticSearch).to receive(:new).and_return(semantic_search)
        allow(semantic_search).to receive(:cached_query?).with(query).and_return(true)
        allow(semantic_search).to receive(:search_for_topics).with(
          query,
          1,
          hyde: false,
        ).and_return([])

        100.times { get "/discourse-ai/embeddings/quick-search.json?q=#{query}" }

        expect(response.status).to eq(200)
      end
    end
  end
end
