# frozen_string_literal: true

RSpec.describe DiscourseAi::Embeddings::Strategies::Truncation do
  subject(:truncation) { described_class.new }

  fab!(:open_ai_embedding_def)
  let(:prefix) { "I come first:" }

  before { enable_current_plugin }

  describe "#prepare_target_text" do
    before { SiteSetting.max_post_length = 100_000 }

    fab!(:topic)
    fab!(:post) do
      Fabricate(:post, topic: topic, raw: "Baby, bird, bird, bird\nBird is the word\n" * 500)
    end
    fab!(:post) do
      Fabricate(
        :post,
        topic: topic,
        raw: "Don't you know about the bird?\nEverybody knows that the bird is a word\n" * 400,
      )
    end
    fab!(:post) { Fabricate(:post, topic: topic, raw: "Surfin' bird\n" * 800) }
    fab!(:open_ai_embedding_def)

    it "truncates a topic" do
      prepared_text = truncation.prepare_target_text(topic, open_ai_embedding_def)

      expect(open_ai_embedding_def.tokenizer.size(prepared_text)).to be <=
        open_ai_embedding_def.max_sequence_length
    end

    it "includes embed prefix" do
      open_ai_embedding_def.update!(embed_prompt: prefix)

      prepared_text = truncation.prepare_target_text(topic, open_ai_embedding_def)

      expect(prepared_text.starts_with?(prefix)).to eq(true)
    end

    context "if topic contains more tokens in cooked posts than embeddings max sequence lenght" do
      before { open_ai_embedding_def.update!(max_sequence_length: 100) }

      it "applies TEXT_TO_HTML_TOKEN_RATIO multiplier for post content collection" do
        # Create posts with known token counts to test the ratio logic
        large_topic = Fabricate(:topic)
        post_content = "This is a test post with some content"
        first_reply = Fabricate(:post, topic: large_topic, raw: "1: #{post_content}")
        tokenizer = open_ai_embedding_def.tokenizer
        max_length = open_ai_embedding_def.max_sequence_length - 2

        # Create posts that would exceed max_length but not max_length * 3
        expected_size = tokenizer.size(first_reply.cooked)

        # Calculate how many posts we need to exceed max_length but stay under max_length * 3
        posts_needed = (max_length / expected_size) + 1

        posts_needed.times do |i|
          Fabricate(:post, topic: large_topic, raw: "#{i + 1}: #{post_content}")
        end

        prepared_text = truncation.prepare_target_text(large_topic, open_ai_embedding_def)

        # Should still be within max_length after HTML stripping and tokenization
        expect(tokenizer.size(prepared_text)).to be <= max_length

        # Should contain content from multiple posts due to the 3x multiplier
        expect(prepared_text).to include("#{posts_needed}: This is a test post with some content")
      end
    end
  end

  describe "#prepare_query_text" do
    context "when search is asymmetric" do
      it "includes search prefix" do
        open_ai_embedding_def.update!(search_prompt: prefix)

        prepared_query_text =
          truncation.prepare_query_text("searching", open_ai_embedding_def, asymmetric: true)

        expect(prepared_query_text.starts_with?(prefix)).to eq(true)
      end
    end

    context "when search is not asymmetric" do
      it "does not include search prefix" do
        open_ai_embedding_def.update!(search_prompt: prefix)

        prepared_query_text =
          truncation.prepare_query_text("searching", open_ai_embedding_def, asymmetric: false)

        expect(prepared_query_text).to eq("searching")
        expect(prepared_query_text.starts_with?(prefix)).to eq(false)
      end

      it "defaults to not asymmetric when parameter is not provided" do
        open_ai_embedding_def.update!(search_prompt: prefix)

        prepared_query_text = truncation.prepare_query_text("searching", open_ai_embedding_def)

        expect(prepared_query_text).to eq("searching")
        expect(prepared_query_text.starts_with?(prefix)).to eq(false)
      end
    end
  end
end
