# frozen_string_literal: true

RSpec.describe DiscourseAi::InferredConcepts::Classifier do
  subject(:classifier) { described_class.new }

  fab!(:vector_def, :cloudflare_embedding_def)
  fab!(:concept_1) do
    Fabricate(:inferred_concept, name: "Caching", description: "HTTP and Redis caching")
  end
  fab!(:concept_2) { Fabricate(:inferred_concept, name: "Security", description: "Auth and TLS") }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_embeddings_selected_model = vector_def.id
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.inferred_concepts_enabled = true
  end

  describe "#classify" do
    it "returns empty results for blank content or empty candidates when allow_new is false" do
      expect(classifier.classify("", candidates: [concept_1])).to eq(
        { matches: [], proposed_new: [] },
      )
      expect(classifier.classify("Some content", candidates: [], allow_new: false)).to eq(
        { matches: [], proposed_new: [] },
      )
    end

    it "validates matches, filters low relevance/hallucinated IDs, and sanitizes proposed concepts" do
      response = {
        matches: [
          { concept_id: concept_1.id, relevance: 0.7, primary: false },
          { concept_id: concept_1.id, relevance: 1.4, primary: true },
          { concept_id: concept_2.id, relevance: 0.35, primary: false },
          { concept_id: 999_999, relevance: 0.9, primary: false },
        ],
        proposed_new: [
          {
            name: "  Edge Caching  ",
            description: "  CDN cache invalidation rules.  ",
            parent_concept_id: concept_1.id,
          },
          {
            name: "edge caching",
            description: "Duplicate case-insensitive name",
            parent_concept_id: 0,
          },
          {
            name: "Rate Limiting",
            description: "Protecting endpoints from abuse",
            parent_concept_id: 999_999,
          },
          { name: "   ", description: "Should be dropped", parent_concept_id: 0 },
        ],
      }

      result =
        DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
          classifier.classify(
            "Discussing edge caching and rate limiting",
            candidates: [concept_1, concept_2],
          )
        end

      expect(result[:matches]).to eq([{ concept_id: concept_1.id, relevance: 1.0, primary: true }])
      expect(result[:proposed_new]).to eq(
        [
          {
            name: "Edge Caching",
            description: "CDN cache invalidation rules.",
            parent_concept_id: concept_1.id,
          },
          {
            name: "Rate Limiting",
            description: "Protecting endpoints from abuse",
            parent_concept_id: nil,
          },
        ],
      )
    end

    it "uses ConceptMatcher and omits proposed_new when allow_new is false" do
      response = {
        matches: [{ concept_id: concept_2.id, relevance: 0.88, primary: true }],
        proposed_new: [{ name: "Ignored", description: "Ignored", parent_concept_id: 0 }],
      }

      result =
        DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
          classifier.classify(
            "TLS certificate rotation",
            candidates: [concept_1, concept_2],
            allow_new: false,
          )
        end

      expect(result).to eq(
        {
          matches: [{ concept_id: concept_2.id, relevance: 0.88, primary: true }],
          proposed_new: [],
        },
      )
    end
  end
end
