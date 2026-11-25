# frozen_string_literal: true

RSpec.describe DiscourseAi::InferredConcepts::Curator do
  subject(:curator) { described_class.new }

  fab!(:vector_def, :cloudflare_embedding_def)

  let(:base_vector) { Array.new(vector_def.dimensions) { |i| i == 0 ? 1.0 : 0.0 } }
  let(:close_vector) do
    Array.new(vector_def.dimensions) { |i| i == 0 ? 0.99 : (i == 1 ? 0.14 : 0.0) }
  end
  let(:distant_vector) { Array.new(vector_def.dimensions) { |i| i == 2 ? 1.0 : 0.0 } }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_embeddings_selected_model = vector_def.id
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.inferred_concepts_enabled = true
  end

  describe "#find_duplicate_clusters" do
    it "clusters nearby concepts across different letters while excluding distant and retired concepts" do
      kubernetes = Fabricate(:inferred_concept, name: "Kubernetes", status: :active)
      k8s = Fabricate(:inferred_concept, name: "k8s", status: :candidate)
      retired = Fabricate(:inferred_concept, name: "kube-old", status: :retired)
      baking = Fabricate(:inferred_concept, name: "Sourdough Baking", status: :active)

      schema = DiscourseAi::Embeddings::Schema.for(InferredConcept)
      schema.store(kubernetes, base_vector, "k1")
      schema.store(k8s, close_vector, "k2")
      schema.store(retired, base_vector, "k3")
      schema.store(baking, distant_vector, "b1")

      clusters = curator.find_duplicate_clusters

      expect(clusters.size).to eq(1)
      expect(clusters.first).to contain_exactly(kubernetes, k8s)
    end

    it "bounds connected components to max_cluster_size" do
      first = Fabricate(:inferred_concept, name: "Alpha Container", status: :active)
      second = Fabricate(:inferred_concept, name: "Beta Container", status: :active)
      third = Fabricate(:inferred_concept, name: "Gamma Container", status: :active)

      schema = DiscourseAi::Embeddings::Schema.for(InferredConcept)
      schema.store(first, base_vector, "c1")
      schema.store(second, close_vector, "c2")
      schema.store(third, base_vector, "c3")

      clusters = curator.find_duplicate_clusters(max_cluster_size: 2)

      expect(clusters.all? { |cluster| cluster.size <= 2 }).to eq(true)
      expect(clusters.flatten).to contain_exactly(first, third)
    end
  end

  describe "#deduplicate_clusters!" do
    it "merges duplicates and reparents sub-concepts while ignoring invalid IDs" do
      kubernetes = Fabricate(:inferred_concept, name: "Kubernetes", status: :active)
      k8s = Fabricate(:inferred_concept, name: "k8s", status: :candidate)
      helm = Fabricate(:inferred_concept, name: "Helm", status: :active)

      schema = DiscourseAi::Embeddings::Schema.for(InferredConcept)
      schema.store(kubernetes, base_vector, "k1")
      schema.store(k8s, close_vector, "k2")
      schema.store(helm, close_vector, "k3")

      topic = Fabricate(:topic)
      InferredConceptTopic.create!(
        inferred_concept: k8s,
        topic: topic,
        relevance: 0.9,
        primary: true,
      )

      response = {
        merges: [
          {
            canonical_id: kubernetes.id,
            merge_ids: [k8s.id, 999_999],
            description: "Kubernetes container orchestration",
          },
        ],
        reparents: [
          { concept_id: helm.id, parent_concept_id: kubernetes.id },
          { concept_id: k8s.id, parent_concept_id: kubernetes.id },
        ],
      }

      stats =
        DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
          curator.deduplicate_clusters!
        end

      expect(stats).to eq(
        { clusters_processed: 1, merges_applied: 1, concepts_retired: 1, reparents_applied: 1 },
      )
      expect(k8s.reload).to be_retired
      expect(kubernetes.reload.aliases).to include("k8s")
      expect(kubernetes.description).to eq("Kubernetes container orchestration")
      expect(kubernetes.topics).to contain_exactly(topic)
      expect(helm.reload.parent).to eq(kubernetes)
    end
  end

  describe "#prune_stale_candidates!" do
    it "destroys low-usage stale candidates, preserves recent ones, and promotes qualifying candidates" do
      stale_unused =
        Fabricate(
          :inferred_concept,
          name: "Niche Term",
          status: :candidate,
          created_at: 45.days.ago,
        )
      stale_qualifying =
        Fabricate(
          :inferred_concept,
          name: "Rising Term",
          status: :candidate,
          created_at: 45.days.ago,
        )
      fresh_candidate =
        Fabricate(:inferred_concept, name: "Fresh Term", status: :candidate, created_at: 5.days.ago)
      old_active =
        Fabricate(:inferred_concept, name: "Established", status: :active, created_at: 90.days.ago)

      2.times do
        InferredConceptTopic.create!(inferred_concept: stale_qualifying, topic: Fabricate(:topic))
      end

      DiscourseAi::Embeddings::Schema.for(InferredConcept).store(
        stale_unused,
        base_vector,
        "stale-vec",
      )

      stats = curator.prune_stale_candidates!(stale_after: 30.days.ago)

      expect(stats).to eq({ pruned_candidates: 1, promoted_candidates: 1 })
      expect(InferredConcept.find_by(id: stale_unused.id)).to be_nil
      expect(
        DiscourseAi::Embeddings::Schema.for(InferredConcept).find_by_target(stale_unused),
      ).to be_nil
      expect(stale_qualifying.reload).to be_active
      expect(fresh_candidate.reload).to be_candidate
      expect(old_active.reload).to be_active
    end
  end

  describe "#enqueue_missing_embeddings" do
    it "enqueues generation jobs only for non-retired concepts missing embeddings" do
      embedded = Fabricate(:inferred_concept, name: "Embedded", status: :active)
      missing = Fabricate(:inferred_concept, name: "Missing", status: :active)
      retired_missing = Fabricate(:inferred_concept, name: "Retired Missing", status: :retired)

      DiscourseAi::Embeddings::Schema.for(InferredConcept).store(embedded, base_vector, "ok")

      expect do
        count = curator.enqueue_missing_embeddings
        expect(count).to eq(1)
      end.to change { Jobs::GenerateEmbeddings.jobs.size }.by(1)

      job_args = Jobs::GenerateEmbeddings.jobs.last["args"].first
      expect(job_args["target_type"]).to eq("InferredConcept")
      expect(job_args["target_id"]).to eq(missing.id)
      expect(retired_missing.reload).to be_retired
    end
  end

  describe "#reconcile_retired_associations!" do
    it "migrates stray topic and post associations from retired duplicates to surviving canonical concepts" do
      canonical =
        Fabricate(:inferred_concept, name: "Kubernetes", aliases: ["k8s"], status: :active)
      retired_dup = Fabricate(:inferred_concept, name: "k8s", status: :retired)
      standalone_retired = Fabricate(:inferred_concept, name: "obsolete", status: :retired)

      topic = Fabricate(:topic)
      post = Fabricate(:post)
      standalone_topic = Fabricate(:topic)

      InferredConceptTopic.create!(
        inferred_concept: canonical,
        topic: topic,
        relevance: 0.6,
        primary: false,
      )
      InferredConceptTopic.create!(
        inferred_concept: retired_dup,
        topic: topic,
        relevance: 0.92,
        primary: true,
      )
      InferredConceptPost.create!(
        inferred_concept: retired_dup,
        post: post,
        relevance: 0.88,
        primary: true,
      )
      InferredConceptTopic.create!(
        inferred_concept: standalone_retired,
        topic: standalone_topic,
        relevance: 0.8,
      )

      expect(curator.reconcile_retired_associations!).to eq(1)

      link = InferredConceptTopic.find_by!(inferred_concept: canonical, topic: topic)
      expect(link.relevance).to eq(0.92)
      expect(link.primary).to eq(true)
      expect(InferredConceptPost.find_by!(inferred_concept: canonical, post: post).relevance).to eq(
        0.88,
      )
      expect(InferredConceptTopic.where(inferred_concept_id: retired_dup.id)).to be_empty
      expect(InferredConceptPost.where(inferred_concept_id: retired_dup.id)).to be_empty
      expect(standalone_retired.topics.reload).to contain_exactly(standalone_topic)
    end
  end

  describe "#curate!" do
    it "returns zero stats when embeddings are disabled" do
      SiteSetting.ai_embeddings_enabled = false

      expect(curator.curate!).to eq(
        {
          reconciled_retired: 0,
          clusters_processed: 0,
          merges_applied: 0,
          concepts_retired: 0,
          reparents_applied: 0,
          pruned_candidates: 0,
          promoted_candidates: 0,
          embeddings_enqueued: 0,
        },
      )
    end

    it "merges a stale candidate matching an active concept before pruning runs" do
      canonical =
        Fabricate(:inferred_concept, name: "Kubernetes", status: :active, created_at: 60.days.ago)
      stale_synonym =
        Fabricate(:inferred_concept, name: "k8s", status: :candidate, created_at: 45.days.ago)
      topic = Fabricate(:topic)
      InferredConceptTopic.create!(inferred_concept: stale_synonym, topic: topic, relevance: 0.9)

      schema = DiscourseAi::Embeddings::Schema.for(InferredConcept)
      schema.store(canonical, base_vector, "k1")
      schema.store(stale_synonym, close_vector, "k2")

      response = {
        merges: [{ canonical_id: canonical.id, merge_ids: [stale_synonym.id], description: "" }],
        reparents: [],
      }

      stats =
        DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
          curator.curate!(stale_after: 30.days.ago)
        end

      expect(stats[:merges_applied]).to eq(1)
      expect(stats[:pruned_candidates]).to eq(0)
      expect(canonical.reload.topics).to contain_exactly(topic)
      expect(stale_synonym.reload).to be_retired
    end
  end
end
