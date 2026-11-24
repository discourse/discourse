# frozen_string_literal: true

RSpec.describe DiscourseAi::InferredConcepts::CandidateRetriever do
  subject(:retriever) { described_class.new }

  before { enable_current_plugin }

  describe "#retrieve" do
    fab!(:active_concept) { Fabricate(:inferred_concept, name: "Caching", status: :active) }
    fab!(:candidate_concept) { Fabricate(:inferred_concept, name: "CDN", status: :candidate) }
    fab!(:retired_concept) { Fabricate(:inferred_concept, name: "Obsolete", status: :retired) }

    it "returns non-retired concepts ordered active-first when embeddings are disabled" do
      SiteSetting.ai_embeddings_enabled = false

      results = retriever.retrieve(content: "HTTP caching")

      expect(results).to contain_exactly(active_concept, candidate_concept)
      expect(results.first).to eq(active_concept)
      expect(results).not_to include(retired_concept)
    end

    it "surfaces matching concepts past the limit via lexical fallback when embeddings are disabled" do
      SiteSetting.ai_embeddings_enabled = false

      33.times { |index| Fabricate(:inferred_concept, name: "unrelated_#{index}", status: :active) }
      alias_match =
        Fabricate(
          :inferred_concept,
          name: "Container Orchestration",
          aliases: ["k8s"],
          description: "Cluster scheduling and autoscaling",
          status: :active,
        )
      name_match =
        Fabricate(
          :inferred_concept,
          name: "Rate Limiting",
          description: "API request throttling",
          status: :active,
        )

      results =
        retriever.retrieve(
          content: "Configuring rate limiting and k8s autoscaling for the ingress controller",
          limit: 30,
        )

      expect(results.length).to eq(30)
      expect(results.first(2)).to contain_exactly(name_match, alias_match)
    end

    context "when embeddings are enabled" do
      fab!(:vector_def, :cloudflare_embedding_def)
      fab!(:topic)

      let(:target_vector) { [0.9, 0.1] + ([0.0] * (vector_def.dimensions - 2)) }
      let(:near_vector) { [0.89, 0.11] + ([0.0] * (vector_def.dimensions - 2)) }
      let(:far_vector) { [0.0, 1.0] + ([0.0] * (vector_def.dimensions - 2)) }

      before do
        SiteSetting.ai_embeddings_selected_model = vector_def.id
        SiteSetting.ai_embeddings_enabled = true

        concepts_schema = DiscourseAi::Embeddings::Schema.for(InferredConcept)
        concepts_schema.store(active_concept, far_vector, "d1")
        concepts_schema.store(candidate_concept, near_vector, "d2")
        concepts_schema.store(retired_concept, target_vector, "d3")
      end

      it "reuses a stored topic embedding without calling the embedding API and excludes retired concepts" do
        DiscourseAi::Embeddings::Schema.for(Topic).store(topic, target_vector, "topic-digest")
        unembedded = Fabricate(:inferred_concept, name: "Unembedded", status: :active)

        allow(DiscourseAi::Embeddings::Vector).to receive(:instance).and_call_original

        results = retriever.retrieve(content: "irrelevant", target: topic, limit: 3)

        expect(DiscourseAi::Embeddings::Vector).not_to have_received(:instance)
        expect(results.first(2)).to eq([candidate_concept, active_concept])
        expect(results).to include(unembedded)
        expect(results).not_to include(retired_concept)
      end

      it "falls back to database ordering when embedding provider is paused" do
        DiscourseAi::Embeddings::ProviderHealth.request!(vector_def) do
          raise DiscourseAi::Inference::EmbeddingInferenceError.new(
                  provider: vector_def.provider,
                  category: :authentication_failed,
                )
        end
      rescue DiscourseAi::Inference::EmbeddingInferenceError
        nil
      ensure
        results = retriever.retrieve(content: "caching query", limit: 10)
        expect(results).to contain_exactly(active_concept, candidate_concept)
        expect(results).not_to include(retired_concept)
      end
    end
  end
end
