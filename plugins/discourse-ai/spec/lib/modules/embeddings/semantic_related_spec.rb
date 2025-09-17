# frozen_string_literal: true

describe DiscourseAi::Embeddings::SemanticRelated do
  subject(:semantic_related) { described_class.new }

  fab!(:target) { Fabricate(:topic) }
  fab!(:normal_topic_1) { Fabricate(:topic) }
  fab!(:normal_topic_2) { Fabricate(:topic) }
  fab!(:normal_topic_3) { Fabricate(:topic) }
  fab!(:unlisted_topic) { Fabricate(:topic, visible: false) }
  fab!(:private_topic) { Fabricate(:private_message_topic) }
  fab!(:secured_category) { Fabricate(:category, read_restricted: true) }
  fab!(:secured_category_topic) { Fabricate(:topic, category: secured_category) }
  fab!(:closed_topic) { Fabricate(:topic, closed: true) }

  fab!(:vector_def) { Fabricate(:embedding_definition) }

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

      before do
        SiteSetting.ai_embeddings_semantic_related_age_penalty = 1.5
        SiteSetting.ai_embeddings_semantic_related_age_time_scale = 30 # Use 30 days for more dramatic effect in tests

        # Create embeddings for test topics
        embedding = Array.new(1024) { rand }
        schema = DiscourseAi::Embeddings::Schema.for(Topic)

        [target, newer_topic, older_topic].each do |topic|
          schema.store(topic, embedding, "test_digest_#{topic.id}")
        end

        described_class.clear_cache_for(target)
      end

      it "prioritizes newer topics over older ones with same similarity" do
        # Mock the similarity search to return consistent embeddings for all topics
        allow_any_instance_of(DiscourseAi::Embeddings::Schema).to receive(
          :symmetric_similarity_search,
        ).and_call_original

        results = semantic_related.related_topic_ids_for(target)

        expect(results).to include(newer_topic.id)
        expect(results).to include(older_topic.id)

        # Newer topic should appear before older topic due to age penalty
        newer_index = results.index(newer_topic.id)
        older_index = results.index(older_topic.id)
        expect(newer_index).to be < older_index if newer_index && older_index
      end

      it "uses no age penalty when setting is 0.0" do
        SiteSetting.ai_embeddings_semantic_related_age_penalty = 0.0
        described_class.clear_cache_for(target)

        # Should work the same as without age penalty
        expect { semantic_related.related_topic_ids_for(target) }.not_to raise_error
      end

      it "handles age penalty parameter correctly in schema" do
        schema = DiscourseAi::Embeddings::Schema.for(Topic)

        expect { schema.symmetric_similarity_search(target, age_penalty: 1.5) }.not_to raise_error

        expect { schema.symmetric_similarity_search(target, age_penalty: 0.0) }.not_to raise_error
      end

      it "respects different time scale settings" do
        # Test with a different time scale that makes the penalty less aggressive
        SiteSetting.ai_embeddings_semantic_related_age_time_scale = 365 # 1 year time scale
        SiteSetting.ai_embeddings_semantic_related_age_penalty = 0.3 # Gentle penalty
        described_class.clear_cache_for(target)

        expect { semantic_related.related_topic_ids_for(target) }.not_to raise_error
      end
    end
  end
end
