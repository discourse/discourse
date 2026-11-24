# frozen_string_literal: true

RSpec.describe DiscourseAi::InferredConcepts::Manager do
  subject(:manager) { described_class.new }

  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic, post_number: 1, raw: "Deep dive into Ruby caching") }
  fab!(:concept1) { Fabricate(:inferred_concept, name: "programming", aliases: ["coding"]) }
  fab!(:concept2) { Fabricate(:inferred_concept, name: "testing") }
  fab!(:retired_concept) { Fabricate(:inferred_concept, name: "deprecated", status: :retired) }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.inferred_concepts_enabled = true
  end

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

    it "handles empty concept list" do
      InferredConcept.destroy_all
      expect { manager.deduplicate_concepts_by_letter }.not_to raise_error
    end
  end
end
