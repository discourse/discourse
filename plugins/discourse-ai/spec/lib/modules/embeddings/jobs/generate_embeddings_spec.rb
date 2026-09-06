# frozen_string_literal: true

RSpec.describe Jobs::GenerateEmbeddings do
  subject(:job) { described_class.new }

  fab!(:vector_def, :embedding_definition)

  before { enable_current_plugin }

  describe "#execute" do
    before do
      SiteSetting.ai_embeddings_selected_model = vector_def.id
      SiteSetting.ai_embeddings_enabled = true
    end

    after { DiscourseAi::Embeddings::ProviderHealth.clear!(vector_def) }

    fab!(:topic)
    fab!(:post) { Fabricate(:post, post_number: 1, topic: topic) }

    let(:topics_schema) { DiscourseAi::Embeddings::Schema.for(Topic) }
    let(:posts_schema) { DiscourseAi::Embeddings::Schema.for(Post) }

    it "works for topics" do
      expected_embedding = [0.0038493] * vector_def.dimensions

      text = vector_def.prepare_target_text(topic)

      EmbeddingsGenerationStubs.hugging_face_service(text, expected_embedding)

      job.execute(target_id: topic.id, target_type: "Topic")

      expect(topics_schema.find_by_embedding(expected_embedding).topic_id).to eq(topic.id)
    end

    it "works for posts" do
      expected_embedding = [0.0038493] * vector_def.dimensions

      text = vector_def.prepare_target_text(post)
      EmbeddingsGenerationStubs.hugging_face_service(text, expected_embedding)

      job.execute(target_id: post.id, target_type: "Post")

      expect(posts_schema.find_by_embedding(expected_embedding).post_id).to eq(post.id)
    end

    it "quietly skips jobs after a terminal provider failure" do
      error =
        DiscourseAi::Inference::EmbeddingInferenceError.new(
          provider: vector_def.provider,
          category: :authentication_failed,
        )
      expect do
        DiscourseAi::Embeddings::ProviderHealth.request!(vector_def) { raise error }
      end.to raise_error(DiscourseAi::Inference::EmbeddingInferenceError)

      expect { job.execute(target_id: topic.id, target_type: "Topic") }.not_to raise_error
      expect(a_request(:post, vector_def.url)).not_to have_been_made
    end
  end
end
