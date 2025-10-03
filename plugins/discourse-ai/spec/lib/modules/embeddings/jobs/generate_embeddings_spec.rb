# frozen_string_literal: true

RSpec.describe Jobs::GenerateEmbeddings do
  subject(:job) { described_class.new }

  fab!(:vector_def) { Fabricate(:embedding_definition) }

  before { enable_current_plugin }

  describe "#execute" do
    before do
      SiteSetting.ai_embeddings_selected_model = vector_def.id
      SiteSetting.ai_embeddings_enabled = true
    end

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
  end
end
