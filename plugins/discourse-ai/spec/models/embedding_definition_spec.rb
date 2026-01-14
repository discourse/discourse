# frozen_string_literal: true

describe EmbeddingDefinition do
  fab!(:embedding_definition, :open_ai_embedding_def)
  fab!(:gemini_embedding_definition, :gemini_embedding_def)

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
