# frozen_string_literal: true

RSpec.describe DiscourseAi::Embeddings::Vector do
  before { enable_current_plugin }

  shared_examples "generates and store embeddings using a vector definition" do
    subject(:vector) { described_class.new(vdef) }

    let(:expected_embedding_1) { [0.0038493] * vdef.dimensions }
    let(:expected_embedding_2) { [0.0037684] * vdef.dimensions }

    before { SiteSetting.ai_embeddings_selected_model = vdef.id }

    let(:topics_schema) { DiscourseAi::Embeddings::Schema.for(Topic) }
    let(:posts_schema) { DiscourseAi::Embeddings::Schema.for(Post) }

    fab!(:topic)
    fab!(:post) { Fabricate(:post, post_number: 1, topic: topic) }
    fab!(:post2) { Fabricate(:post, post_number: 2, topic: topic) }

    describe "#vector_from" do
      it "creates a vector from a given string" do
        text = "This is a piece of text"
        stub_vector_mapping(text, expected_embedding_1)

        expect(vector.vector_from(text)).to eq(expected_embedding_1)
      end

      it "passes asymmetric parameter to prepare_query_text correctly" do
        text = "This is a piece of text"
        vdef.update!(search_prompt: "Search: ")
        prepared_text = vdef.prepare_query_text(text, asymmetric: true)
        stub_vector_mapping(prepared_text, expected_embedding_1)

        allow(vdef).to receive(:prepare_query_text).and_call_original

        vector.vector_from(text, true)

        expect(vdef).to have_received(:prepare_query_text).with(text, asymmetric: true)
      end

      it "defaults asymmetric parameter to false" do
        text = "This is a piece of text"
        stub_vector_mapping(text, expected_embedding_1)

        allow(vdef).to receive(:prepare_query_text).and_call_original

        vector.vector_from(text)

        expect(vdef).to have_received(:prepare_query_text).with(text, asymmetric: false)
      end

      it "handles asymmetric parameter explicitly set to false" do
        text = "This is a piece of text"
        stub_vector_mapping(text, expected_embedding_1)

        allow(vdef).to receive(:prepare_query_text).and_call_original

        vector.vector_from(text, false)

        expect(vdef).to have_received(:prepare_query_text).with(text, asymmetric: false)
      end
    end

    describe "#generate_representation_from" do
      it "creates a vector from a topic and stores it in the database" do
        text = vdef.prepare_target_text(topic)
        stub_vector_mapping(text, expected_embedding_1)

        vector.generate_representation_from(topic)

        expect(topics_schema.find_by_embedding(expected_embedding_1).topic_id).to eq(topic.id)
      end

      it "creates a vector from a post and stores it in the database" do
        text = vdef.prepare_target_text(post2)
        stub_vector_mapping(text, expected_embedding_1)

        vector.generate_representation_from(post)

        expect(posts_schema.find_by_embedding(expected_embedding_1).post_id).to eq(post.id)
      end
    end

    describe "#gen_bulk_reprensentations" do
      fab!(:topic_2, :topic)
      fab!(:post_2_1) { Fabricate(:post, post_number: 1, topic: topic_2) }
      fab!(:post_2_2) { Fabricate(:post, post_number: 2, topic: topic_2) }

      it "creates a vector for each object in the relation" do
        text = vdef.prepare_target_text(topic)

        text2 = vdef.prepare_target_text(topic_2)

        stub_vector_mapping(text, expected_embedding_1)
        stub_vector_mapping(text2, expected_embedding_2)

        vector.gen_bulk_reprensentations(Topic.where(id: [topic.id, topic_2.id]))

        expect(topics_schema.find_by_embedding(expected_embedding_1).topic_id).to eq(topic.id)
      end

      it "does nothing if passed record has no content" do
        expect { vector.gen_bulk_reprensentations([Topic.new]) }.not_to raise_error
      end

      it "doesn't ask for a new embedding if digest is the same" do
        text = vdef.prepare_target_text(topic)
        stub_vector_mapping(text, expected_embedding_1)

        original_vector_gen = Time.zone.parse("2021-06-04 10:00")

        freeze_time(original_vector_gen) do
          vector.gen_bulk_reprensentations(Topic.where(id: [topic.id]))
        end
        # check vector exists
        expect(topics_schema.find_by_embedding(expected_embedding_1).topic_id).to eq(topic.id)

        vector.gen_bulk_reprensentations(Topic.where(id: [topic.id]))

        expect(topics_schema.find_by_target(topic).updated_at).to eq_time(original_vector_gen)
      end

      context "when one of the concurrently generated embeddings fails" do
        it "still processes the succesful ones" do
          text = vdef.prepare_target_text(topic)

          text2 = vdef.prepare_target_text(topic_2)

          stub_vector_mapping(text, expected_embedding_1)
          stub_vector_mapping(text2, expected_embedding_2, result_status: 429)

          vector.gen_bulk_reprensentations(Topic.where(id: [topic.id, topic_2.id]))

          expect(topics_schema.find_by_embedding(expected_embedding_1).topic_id).to eq(topic.id)
          expect(topics_schema.find_by_target(topic_2)).to be_nil
        end
      end
    end
  end

  context "with open_ai as the provider" do
    fab!(:vdef, :open_ai_embedding_def)

    def stub_vector_mapping(text, expected_embedding, result_status: 200)
      EmbeddingsGenerationStubs.openai_service(
        vdef.lookup_custom_param("model_name"),
        text,
        expected_embedding,
        result_status: result_status,
      )
    end

    it_behaves_like "generates and store embeddings using a vector definition"

    context "when matryoshka_dimensions is enabled" do
      it "passes the dimensions param" do
        shorter_dimensions = 10
        vdef.update!(dimensions: shorter_dimensions, matryoshka_dimensions: true)
        text = "This is a piece of text"
        short_expected_embedding = [0.0038493] * shorter_dimensions

        EmbeddingsGenerationStubs.openai_service(
          vdef.lookup_custom_param("model_name"),
          text,
          short_expected_embedding,
          extra_args: {
            dimensions: shorter_dimensions,
          },
        )

        expect(described_class.new(vdef).vector_from(text)).to eq(short_expected_embedding)
      end
    end
  end

  context "with hugging_face as the provider" do
    fab!(:vdef, :embedding_definition)

    def stub_vector_mapping(text, expected_embedding, result_status: 200)
      EmbeddingsGenerationStubs.hugging_face_service(
        text,
        expected_embedding,
        result_status: result_status,
      )
    end

    it_behaves_like "generates and store embeddings using a vector definition"
  end

  context "with google as the provider" do
    fab!(:vdef, :gemini_embedding_def)

    def stub_vector_mapping(text, expected_embedding, result_status: 200)
      EmbeddingsGenerationStubs.gemini_service(
        vdef.api_key,
        text,
        expected_embedding,
        result_status: result_status,
      )
    end

    it_behaves_like "generates and store embeddings using a vector definition"
  end

  context "with cloudflare as the provider" do
    fab!(:vdef, :cloudflare_embedding_def)

    def stub_vector_mapping(text, expected_embedding, result_status: 200)
      EmbeddingsGenerationStubs.cloudflare_service(
        text,
        expected_embedding,
        result_status: result_status,
      )
    end

    it_behaves_like "generates and store embeddings using a vector definition"
  end
end
