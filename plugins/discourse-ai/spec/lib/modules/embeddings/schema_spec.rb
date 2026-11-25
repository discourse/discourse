# frozen_string_literal: true

RSpec.describe DiscourseAi::Embeddings::Schema do
  subject(:posts_schema) { described_class.for(Post) }

  fab!(:vector_def, :cloudflare_embedding_def)
  let(:embeddings) { [0.0038490295] * vector_def.dimensions }
  fab!(:post) { Fabricate(:post, post_number: 1) }
  let(:digest) { OpenSSL::Digest.hexdigest("SHA1", "test") }

  before do
    enable_current_plugin
    SiteSetting.ai_embeddings_selected_model = vector_def.id
    posts_schema.store(post, embeddings, digest)
  end

  describe "#find_by_target" do
    it "gets you the post_id of the record that matches the post" do
      embeddings_record = posts_schema.find_by_target(post)

      expect(embeddings_record.digest).to eq(digest)
      expect(JSON.parse(embeddings_record.embeddings)).to eq(embeddings)
    end
  end

  describe "#find_by_embedding" do
    it "gets you the record that matches the embedding" do
      embeddings_record = posts_schema.find_by_embedding(embeddings)

      expect(embeddings_record.digest).to eq(digest)
      expect(embeddings_record.post_id).to eq(post.id)
    end
  end

  describe "similarity searches" do
    fab!(:post_2, :post)
    let(:similar_embeddings) { [0.0038490294] * vector_def.dimensions }

    describe "#symmetric_similarity_search" do
      before { posts_schema.store(post_2, similar_embeddings, digest) }

      it "returns target_id with similar embeddings" do
        similar_records = posts_schema.symmetric_similarity_search(post)

        expect(similar_records.map(&:post_id)).to contain_exactly(post.id, post_2.id)
      end

      it "let's you apply additional scopes to filter results further" do
        similar_records =
          posts_schema.symmetric_similarity_search(post) do |builder|
            builder.where("post_id = ?", post_2.id)
          end

        expect(similar_records.map(&:post_id)).to contain_exactly(post_2.id)
      end

      it "let's you join on additional tables and combine with additional scopes" do
        similar_records =
          posts_schema.symmetric_similarity_search(post) do |builder|
            builder.join("posts p on p.id = post_id")
            builder.join("topics t on t.id = p.topic_id")
            builder.where("t.id = ?", post_2.topic_id)
          end

        expect(similar_records.map(&:post_id)).to contain_exactly(post_2.id)
      end
    end

    describe "#asymmetric_similarity_search" do
      it "returns target_id with similar embeddings" do
        similar_records =
          posts_schema.asymmetric_similarity_search(similar_embeddings, limit: 1, offset: 0)

        expect(similar_records.map(&:post_id)).to contain_exactly(post.id)
      end

      it "let's you apply additional scopes to filter results further" do
        similar_records =
          posts_schema.asymmetric_similarity_search(
            similar_embeddings,
            limit: 1,
            offset: 0,
          ) { |builder| builder.where("post_id <> ?", post.id) }

        expect(similar_records.map(&:post_id)).to be_empty
      end

      it "let's you join on additional tables and combine with additional scopes" do
        similar_records =
          posts_schema.asymmetric_similarity_search(
            similar_embeddings,
            limit: 1,
            offset: 0,
          ) do |builder|
            builder.join("posts p on p.id = post_id")
            builder.join("topics t on t.id = p.topic_id")
            builder.where("t.id <> ?", post.topic_id)
          end

        expect(similar_records.map(&:post_id)).to be_empty
      end
    end
  end

  describe "InferredConcept embeddings" do
    subject(:concepts_schema) { described_class.for(InferredConcept) }

    fab!(:concept_1) { Fabricate(:inferred_concept, name: "Authentication") }
    fab!(:concept_2) { Fabricate(:inferred_concept, name: "Authorization") }
    let(:concept_embeddings_1) { [0.0038490295] * vector_def.dimensions }
    let(:concept_embeddings_2) { [0.0038490294] * vector_def.dimensions }

    before do
      concepts_schema.store(concept_1, concept_embeddings_1, digest)
      concepts_schema.store(concept_2, concept_embeddings_2, digest)
    end

    it "stores and retrieves inferred concept embeddings" do
      record = concepts_schema.find_by_target(concept_1)

      expect(record.digest).to eq(digest)
      expect(JSON.parse(record.embeddings)).to eq(concept_embeddings_1)
    end

    it "supports asymmetric and symmetric similarity search" do
      asymmetric =
        concepts_schema.asymmetric_similarity_search(concept_embeddings_1, limit: 2, offset: 0)
      symmetric = concepts_schema.symmetric_similarity_search(concept_1)

      expect(asymmetric.map(&:inferred_concept_id)).to contain_exactly(concept_1.id, concept_2.id)
      expect(symmetric.map(&:inferred_concept_id)).to contain_exactly(concept_1.id, concept_2.id)
    end

    it "deletes embeddings for a concept via delete_embeddings_for" do
      described_class.delete_embeddings_for(concept_1)

      expect(concepts_schema.find_by_target(concept_1)).to be_nil
      expect(concepts_schema.find_by_target(concept_2)).to be_present
    end
  end
end
