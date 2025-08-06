# frozen_string_literal: true

describe EmbeddingDefinition do
  fab!(:embedding_definition) { Fabricate(:open_ai_embedding_def) }

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
end
