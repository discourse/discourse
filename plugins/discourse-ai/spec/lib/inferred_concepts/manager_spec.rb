# frozen_string_literal: true

RSpec.describe DiscourseAi::InferredConcepts::Manager do
  subject(:manager) { described_class.new }

  fab!(:vector_def, :cloudflare_embedding_def)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic, post_number: 1, raw: "Deep dive into Ruby caching") }
  fab!(:concept1) { Fabricate(:inferred_concept, name: "programming", aliases: ["coding"]) }
  fab!(:concept2) { Fabricate(:inferred_concept, name: "testing") }
  fab!(:retired_concept) { Fabricate(:inferred_concept, name: "deprecated", status: :retired) }

  let(:sample_vector) { [0.1] * vector_def.dimensions }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_embeddings_selected_model = vector_def.id
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.inferred_concepts_enabled = true

    DiscourseAi::Embeddings::Schema.for(Topic).store(topic, sample_vector, "topic-vec")
    DiscourseAi::Embeddings::Schema.for(Post).store(post, sample_vector, "post-vec")
  end

  after { DiscourseAi::Embeddings::ProviderHealth.clear!(vector_def) }

  describe "#list_concepts" do
    it "returns non-retired concepts sorted by name and respects limit" do
      expect(manager.list_concepts).to eq(%w[programming testing])
      expect(manager.list_concepts(limit: 1)).to eq(["programming"])
    end
  end

  describe "#generate_concepts_from_topic" do
    it "matches existing concepts and stages new candidate concepts in a single pass" do
      response = {
        matches: [{ concept_id: concept1.id, relevance: 0.9, primary: true }],
        proposed_new: [
          {
            name: "Redis Caching",
            description: "In-memory caching with Redis",
            parent_concept_id: concept1.id,
          },
        ],
      }

      applied =
        DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
          manager.generate_concepts_from_topic(topic)
        end

      new_concept = InferredConcept.find_by(name: "Redis Caching")
      expect(new_concept).to be_present
      expect(new_concept).to be_candidate
      expect(new_concept.description).to eq("In-memory caching with Redis")
      expect(new_concept.parent).to eq(concept1)
      expect(applied).to contain_exactly(concept1, new_concept)
      expect(topic.inferred_concepts).to contain_exactly(concept1, new_concept)

      # Re-running with unchanged content skips the LLM call via digest check
      expect(manager.generate_concepts_from_topic(topic)).to contain_exactly(concept1, new_concept)
    end

    it "reuses existing concepts matched by alias and skips retired concepts" do
      response = {
        matches: [],
        proposed_new: [
          { name: "coding", description: "Should reuse programming", parent_concept_id: 0 },
          { name: "deprecated", description: "Should be skipped", parent_concept_id: 0 },
        ],
      }

      applied =
        DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
          manager.generate_concepts_from_topic(topic)
        end

      expect(applied).to contain_exactly(concept1)
      expect(topic.inferred_concepts).to contain_exactly(concept1)
    end

    it "promotes a candidate concept to active once it reaches PROMOTION_THRESHOLD usages" do
      candidate = Fabricate(:inferred_concept, name: "Edge Caching", status: :candidate)
      topic2 = Fabricate(:topic)
      Fabricate(:post, topic: topic2, post_number: 1, raw: "CDN edge caching notes")
      DiscourseAi::Embeddings::Schema.for(Topic).store(topic2, sample_vector, "topic2-vec")

      response = {
        matches: [{ concept_id: candidate.id, relevance: 0.9, primary: true }],
        proposed_new: [],
      }

      DiscourseAi::Completions::Llm.with_prepared_responses([response, response]) do
        manager.generate_concepts_from_topic(topic)
        expect(candidate.reload).to be_candidate

        manager.generate_concepts_from_topic(topic2)
        expect(candidate.reload).to be_active
      end
    end

    it "skips classification when embeddings are disabled or provider is paused" do
      SiteSetting.ai_embeddings_enabled = false
      expect(manager.generate_concepts_from_topic(topic)).to eq([])

      SiteSetting.ai_embeddings_enabled = true
      topic_without_embedding = Fabricate(:topic)
      Fabricate(:post, topic: topic_without_embedding, post_number: 1, raw: "Paused test")
      begin
        DiscourseAi::Embeddings::ProviderHealth.request!(vector_def) do
          raise DiscourseAi::Inference::EmbeddingInferenceError.new(
                  provider: vector_def.provider,
                  category: :authentication_failed,
                )
        end
      rescue DiscourseAi::Inference::EmbeddingInferenceError
        nil
      end

      expect(manager.generate_concepts_from_topic(topic_without_embedding)).to eq([])
    end

    it "skips private messages and deleted targets without calling embeddings or LLMs" do
      pm_topic = Fabricate(:private_message_topic)
      pm_reply = Fabricate(:post, topic: pm_topic, post_number: 2, raw: "Private discussion")
      deleted_topic = Fabricate(:topic, deleted_at: Time.zone.now)

      allow(DiscourseAi::Embeddings::Vector).to receive(:instance)

      expect(manager.generate_concepts_from_topic(pm_topic)).to eq([])
      expect(manager.generate_concepts_from_post(pm_reply)).to eq([])
      expect(manager.generate_concepts_from_topic(deleted_topic)).to eq([])
      expect(DiscourseAi::Embeddings::Vector).not_to have_received(:instance)
    end
  end

  describe "#generate_concepts_from_post" do
    it "classifies and attaches concepts to a post" do
      response = {
        matches: [{ concept_id: concept2.id, relevance: 0.85, primary: true }],
        proposed_new: [],
      }

      applied =
        DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
          manager.generate_concepts_from_post(post)
        end

      expect(applied).to contain_exactly(concept2)
      expect(post.inferred_concepts).to contain_exactly(concept2)
    end
  end

  describe "#match_topic_to_concepts and #match_post_to_concepts" do
    it "matches existing concepts without creating new ones" do
      response = { matches: [{ concept_id: concept1.id, relevance: 0.8, primary: true }] }

      applied_topic =
        DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
          manager.match_topic_to_concepts(topic)
        end
      applied_post =
        DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
          manager.match_post_to_concepts(post)
        end

      expect(applied_topic).to contain_exactly(concept1)
      expect(applied_post).to contain_exactly(concept1)
    end
  end

  describe "#search_topics_by_concept and #search_posts_by_concept" do
    it "finds topics and posts by concept name or alias" do
      concept1.topics << topic
      concept1.posts << post

      expect(manager.search_topics_by_concept("coding")).to contain_exactly(topic)
      expect(manager.search_posts_by_concept("coding")).to contain_exactly(post)
      expect(manager.search_topics_by_concept("nonexistent")).to eq([])
    end
  end

  describe "#match_content_to_concepts" do
    it "matches content against existing non-retired concepts" do
      EmbeddingsGenerationStubs.cloudflare_service("programming guide", sample_vector)
      response = { matches: [{ concept_id: concept1.id, relevance: 0.85, primary: true }] }

      result =
        DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
          manager.match_content_to_concepts("programming guide")
        end

      expect(result).to eq(["programming"])
    end
  end

  describe "#deduplicate_concepts_by_letter" do
    before do
      %w[apple application banana berry cat car dog].each do |name|
        Fabricate(:inferred_concept, name: name)
      end
    end

    it "groups concepts by first letter and deduplicates" do
      finder = instance_double(DiscourseAi::InferredConcepts::Finder)
      allow(DiscourseAi::InferredConcepts::Finder).to receive(:new).and_return(finder)
      allow(finder).to receive(:deduplicate_concepts).at_least(:once).and_return(
        %w[apple banana cat dog],
      )

      expect { manager.deduplicate_concepts_by_letter }.not_to raise_error
    end

    it "preserves retired concepts and their associations when deduplicating active concepts" do
      retired_concept.topics << topic

      finder = instance_double(DiscourseAi::InferredConcepts::Finder)
      allow(DiscourseAi::InferredConcepts::Finder).to receive(:new).and_return(finder)
      allow(finder).to receive(:deduplicate_concepts) do |batch|
        batch.reject { |name| name == "application" }
      end

      manager.deduplicate_concepts_by_letter(per_letter_batch: 100, full_pass_batch: 200)

      expect(InferredConcept.find_by(id: retired_concept.id)).to be_present
      expect(retired_concept.topics.reload).to contain_exactly(topic)
      expect(InferredConcept.find_by(name: "application")).to be_nil
      expect(InferredConcept.find_by(name: "apple")).to be_present
    end

    it "handles empty concept list" do
      InferredConcept.destroy_all
      expect { manager.deduplicate_concepts_by_letter }.not_to raise_error
    end
  end
end
