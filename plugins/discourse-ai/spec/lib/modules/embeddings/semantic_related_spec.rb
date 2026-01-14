# frozen_string_literal: true

describe DiscourseAi::Embeddings::SemanticRelated do
  subject(:semantic_related) { described_class.new }

  fab!(:target, :topic)
  fab!(:normal_topic_1, :topic)
  fab!(:normal_topic_2, :topic)
  fab!(:normal_topic_3, :topic)
  fab!(:unlisted_topic) { Fabricate(:topic, visible: false) }
  fab!(:private_topic, :private_message_topic)
  fab!(:secured_category) { Fabricate(:category, read_restricted: true) }
  fab!(:secured_category_topic) { Fabricate(:topic, category: secured_category) }
  fab!(:closed_topic) { Fabricate(:topic, closed: true) }

  fab!(:vector_def, :embedding_definition)

  before do
    enable_current_plugin
    SiteSetting.ai_embeddings_semantic_related_topics_enabled = true
    SiteSetting.ai_embeddings_selected_model = vector_def.id
    SiteSetting.ai_embeddings_enabled = true
  end

  describe "#related_topic_ids_for" do
    it "returns empty array if AI embeddings are disabled" do
      SiteSetting.ai_embeddings_enabled = false

      expect(semantic_related.related_topic_ids_for(normal_topic_1)).to eq([])
    end

    context "when embeddings do not exist" do
      let(:topic) do
        post = Fabricate(:post)
        topic = post.topic
        described_class.clear_cache_for(target)
        topic
      end

      it "properly generates embeddings if missing" do
        Jobs.run_immediately!

        embedding = Array.new(1024) { 1 }

        WebMock.stub_request(:post, vector_def.url).to_return(
          status: 200,
          body: JSON.dump([embedding]),
        )

        # miss first
        ids = semantic_related.related_topic_ids_for(topic)

        # clear cache so we lookup
        described_class.clear_cache_for(topic)

        # hit cause we queued generation
        ids = semantic_related.related_topic_ids_for(topic)

        # at this point though the only embedding is ourselves
        expect(ids).to eq([topic.id])
      end

      it "queues job only once per 15 minutes" do
        results = nil

        expect_enqueued_with(
          job: :generate_embeddings,
          args: {
            target_id: topic.id,
            target_type: "Topic",
          },
        ) { results = semantic_related.related_topic_ids_for(topic) }

        expect(results).to eq([])

        expect_not_enqueued_with(
          job: :generate_embeddings,
          args: {
            target_id: topic.id,
            target_type: "Topic",
          },
        ) { results = semantic_related.related_topic_ids_for(topic) }

        expect(results).to eq([])
      end
    end

    describe "age penalty functionality" do
      let(:newer_topic) { Fabricate(:topic, bumped_at: 1.day.ago) }
      let(:older_topic) { Fabricate(:topic, bumped_at: 30.days.ago) }
      let(:embedding_builder) do
        ->(*components) { Array.new(vector_def.dimensions) { |idx| components[idx] || 0.0 } }
      end
      let(:store_embeddings) do
        lambda do |target_embedding:, newer_embedding:, older_embedding:|
          schema = DiscourseAi::Embeddings::Schema.for(Topic)
          schema.store(target, target_embedding, "test_digest_#{target.id}")
          schema.store(newer_topic, newer_embedding, "test_digest_#{newer_topic.id}")
          schema.store(older_topic, older_embedding, "test_digest_#{older_topic.id}")
          described_class.clear_cache_for(target)
        end
      end

      it "penalizes older topics for cosine distance models" do
        vector_def.update!(pg_function: "<=>")
        SiteSetting.ai_embeddings_semantic_related_age_time_scale = 1

        target_embedding = embedding_builder.call(1.0, 0.0)
        newer_embedding = embedding_builder.call(0.8, 0.2)
        older_embedding = embedding_builder.call(0.98, 0.02)
        store_embeddings.call(
          target_embedding: target_embedding,
          newer_embedding: newer_embedding,
          older_embedding: older_embedding,
        )

        SiteSetting.ai_embeddings_semantic_related_age_penalty = 0.0
        described_class.clear_cache_for(target)
        without_penalty = semantic_related.related_topic_ids_for(target)
        expect(without_penalty).to include(older_topic.id, newer_topic.id)
        expect(without_penalty.index(older_topic.id)).to be < without_penalty.index(newer_topic.id)

        SiteSetting.ai_embeddings_semantic_related_age_penalty = 2.0
        described_class.clear_cache_for(target)
        with_penalty = semantic_related.related_topic_ids_for(target)
        expect(with_penalty).to include(older_topic.id, newer_topic.id)
        expect(with_penalty.index(newer_topic.id)).to be < with_penalty.index(older_topic.id)
      end

      it "penalizes older topics for negative inner product models" do
        vector_def.update!(pg_function: "<#>")
        SiteSetting.ai_embeddings_semantic_related_age_time_scale = 1

        target_embedding = embedding_builder.call(1.0, 0.0)
        newer_embedding = embedding_builder.call(0.92, 0.08)
        older_embedding = embedding_builder.call(1.1, 0.0)
        store_embeddings.call(
          target_embedding: target_embedding,
          newer_embedding: newer_embedding,
          older_embedding: older_embedding,
        )

        SiteSetting.ai_embeddings_semantic_related_age_penalty = 0.0
        described_class.clear_cache_for(target)
        without_penalty = semantic_related.related_topic_ids_for(target)
        expect(without_penalty).to include(older_topic.id, newer_topic.id)
        expect(without_penalty.index(older_topic.id)).to be < without_penalty.index(newer_topic.id)

        SiteSetting.ai_embeddings_semantic_related_age_penalty = 2.0
        described_class.clear_cache_for(target)
        with_penalty = semantic_related.related_topic_ids_for(target)
        expect(with_penalty).to include(older_topic.id, newer_topic.id)
        expect(with_penalty.index(newer_topic.id)).to be < with_penalty.index(older_topic.id)
      end

      it "uses no age penalty when setting is 0.0" do
        SiteSetting.ai_embeddings_semantic_related_age_penalty = 0.0
        uniform_embedding = embedding_builder.call(0.5, 0.5)
        store_embeddings.call(
          target_embedding: uniform_embedding.dup,
          newer_embedding: uniform_embedding.dup,
          older_embedding: uniform_embedding.dup,
        )

        expect { semantic_related.related_topic_ids_for(target) }.not_to raise_error
      end

      it "handles age penalty parameter correctly in schema" do
        uniform_embedding = embedding_builder.call(0.25, 0.75)
        store_embeddings.call(
          target_embedding: uniform_embedding.dup,
          newer_embedding: uniform_embedding.dup,
          older_embedding: uniform_embedding.dup,
        )

        schema = DiscourseAi::Embeddings::Schema.for(Topic)

        expect { schema.symmetric_similarity_search(target, age_penalty: 1.5) }.not_to raise_error

        expect { schema.symmetric_similarity_search(target, age_penalty: 0.0) }.not_to raise_error
      end

      it "respects different time scale settings" do
        uniform_embedding = embedding_builder.call(0.6, 0.4)
        store_embeddings.call(
          target_embedding: uniform_embedding.dup,
          newer_embedding: uniform_embedding.dup,
          older_embedding: uniform_embedding.dup,
        )

        SiteSetting.ai_embeddings_semantic_related_age_time_scale = 365 # 1 year time scale
        SiteSetting.ai_embeddings_semantic_related_age_penalty = 0.3 # Gentle penalty
        described_class.clear_cache_for(target)

        expect { semantic_related.related_topic_ids_for(target) }.not_to raise_error
      end
    end
  end
end
