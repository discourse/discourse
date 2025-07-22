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
  end

  describe "#prepare_query_text" do
    context "when search is asymetric" do
      it "includes search prefix" do
        open_ai_embedding_def.update!(search_prompt: prefix)

        prepared_query_text =
          truncation.prepare_query_text("searching", open_ai_embedding_def, asymetric: true)

        expect(prepared_query_text.starts_with?(prefix)).to eq(true)
      end
    end
  end
end
