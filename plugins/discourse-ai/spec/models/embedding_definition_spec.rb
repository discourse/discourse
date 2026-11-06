# frozen_string_literal: true

describe EmbeddingDefinition do
  fab!(:embedding_definition, :open_ai_embedding_def)
  fab!(:gemini_embedding_definition, :gemini_embedding_def)

  describe "validations" do
    it "allows valid pg_function values" do
      EmbeddingDefinition.distance_functions.each do |fn|
        embedding_definition.pg_function = fn
        expect(embedding_definition).to be_valid
      end
    end

    it "rejects invalid pg_function values" do
      embedding_definition.pg_function = "'; DROP TABLE users; --"
      expect(embedding_definition).not_to be_valid
      expect(embedding_definition.errors[:pg_function]).to be_present
    end

    it "accepts a Bedrock definition without an API key and derives its URL from the region" do
      definition =
        Fabricate.build(
          :bedrock_embedding_def,
          url: nil,
          provider_params: {
            model_id: "cohere.embed-v4:0",
            region: "eu-west-1",
          },
        )

      expect(definition).to be_valid
      expect(definition.url).to eq("https://bedrock-runtime.eu-west-1.amazonaws.com")
    end

    it "requires a model ID and region for Bedrock definitions" do
      definition = Fabricate.build(:bedrock_embedding_def, url: nil, provider_params: {})

      expect(definition).not_to be_valid
      expect(definition.errors.full_messages).to contain_exactly(
        "model_id can't be blank",
        "region can't be blank",
      )
    end
  end

  describe "#inference_client" do
    before { enable_current_plugin }

    it "signs Bedrock requests with an access key ID stored as a credential" do
      access_key = Fabricate(:ai_secret, secret: "AKIASTORED")
      definition =
        Fabricate(
          :bedrock_embedding_def,
          api_key: "secret-access-key",
          provider_params: {
            model_id: "cohere.embed-v4:0",
            region: "us-east-1",
            access_key_id: access_key.id.to_s,
          },
        )
      invoke_url = "https://bedrock-runtime.us-east-1.amazonaws.com/model/cohere.embed-v4:0/invoke"
      stub_request(:post, invoke_url).to_return(
        status: 200,
        body: { embeddings: { float: [[0.1, 0.2]] } }.to_json,
      )

      expect(definition.inference_client.perform!("hello")).to eq([0.1, 0.2])
      expect(WebMock).to have_requested(:post, invoke_url).with { |request|
        request.headers["Authorization"].start_with?("AWS4-HMAC-SHA256 Credential=AKIASTORED/")
      }
    end
  end

  describe "#prepare_query_text" do
    let(:text) { "test query" }

    before do
      # Set up search prompt to test asymmetric behavior
      embedding_definition.update!(search_prompt: "Search: ")
    end

    it "includes search prompt when asymmetric is true" do
      result = embedding_definition.prepare_query_text(text, asymmetric: true)
      expect(result).to start_with("Search: ")
      expect(result).to include(text)
    end

    it "does not include search prompt when asymmetric is false" do
      result = embedding_definition.prepare_query_text(text, asymmetric: false)
      expect(result).to eq(text)
      expect(result).not_to start_with("Search: ")
    end

    it "defaults to asymmetric false when parameter is not provided" do
      result = embedding_definition.prepare_query_text(text)
      expect(result).to eq(text)
      expect(result).not_to start_with("Search: ")
    end

    it "properly truncates text when needed" do
      long_text = "word " * 1000
      result = embedding_definition.prepare_query_text(long_text)

      # Should be truncated to max_sequence_length - 2
      max_tokens = embedding_definition.max_sequence_length - 2
      expect(embedding_definition.tokenizer.size(result)).to be <= max_tokens
    end
  end

  describe "#gemini_client (private method)" do
    context "when matryoshka_dimensions is false" do
      before { gemini_embedding_definition.update!(matryoshka_dimensions: false) }

      it "creates GeminiEmbeddings client without dimensions" do
        client = gemini_embedding_definition.send(:gemini_client)

        expect(client).to be_a(DiscourseAi::Inference::GeminiEmbeddings)
        expect(client.instance_variable_get(:@dimensions)).to be_nil
      end
    end

    context "when matryoshka_dimensions is true" do
      before { gemini_embedding_definition.update!(matryoshka_dimensions: true) }

      it "creates GeminiEmbeddings client with dimensions" do
        client = gemini_embedding_definition.send(:gemini_client)

        expect(client).to be_a(DiscourseAi::Inference::GeminiEmbeddings)
        expect(client.instance_variable_get(:@dimensions)).to eq(
          gemini_embedding_definition.dimensions,
        )
      end
    end

    it "passes correct parameters to GeminiEmbeddings constructor" do
      allow(DiscourseAi::Inference::GeminiEmbeddings).to receive(:new).and_call_original

      gemini_embedding_definition.send(:gemini_client)

      expect(DiscourseAi::Inference::GeminiEmbeddings).to have_received(:new).with(
        gemini_embedding_definition.endpoint_url,
        gemini_embedding_definition.api_key,
        nil,
      )
    end
  end
end
