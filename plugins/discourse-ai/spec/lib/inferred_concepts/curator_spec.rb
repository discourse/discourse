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
    allow_any_instance_of(DiscourseAi::Embeddings::Vector).to receive(:gen_bulk_reprensentations)
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

    it "clusters concepts with high topic co-occurrence even when embeddings are distant" do
      first = Fabricate(:inferred_concept, name: "Platform Migration", status: :active)
      second = Fabricate(:inferred_concept, name: "Forum Data Transfer", status: :active)

      schema = DiscourseAi::Embeddings::Schema.for(InferredConcept)
      schema.store(first, base_vector, "p1")
      schema.store(second, distant_vector, "p2")

      3.times do
        topic = Fabricate(:topic)
        InferredConceptTopic.create!(inferred_concept: first, topic: topic)
        InferredConceptTopic.create!(inferred_concept: second, topic: topic)
      end

      InferredConceptTopic.create!(inferred_concept: first, topic: Fabricate(:topic))

      expect(curator.find_duplicate_clusters(include_co_occurrence: false)).to be_empty

      clusters = curator.find_duplicate_clusters
      expect(clusters.size).to eq(1)
      expect(clusters.first).to contain_exactly(first, second)
    end

    it "seeds hub-anchored clusters from highest-usage concepts first" do
      hub = Fabricate(:inferred_concept, name: "Hub Theme", status: :active)
      spoke_a = Fabricate(:inferred_concept, name: "Spoke Alpha", status: :active)
      spoke_b = Fabricate(:inferred_concept, name: "Spoke Beta", status: :active)

      5.times { InferredConceptTopic.create!(inferred_concept: hub, topic: Fabricate(:topic)) }

      schema = DiscourseAi::Embeddings::Schema.for(InferredConcept)
      [hub, spoke_a, spoke_b].each_with_index do |concept, idx|
        schema.store(concept, base_vector, "h#{idx}")
      end

      clusters = curator.find_duplicate_clusters(max_cluster_size: 2, include_co_occurrence: false)
      expect(clusters.size).to eq(1)
      expect(clusters.first).to include(hub)
      expect(clusters.first.size).to eq(2)
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

    it "runs multi-pass clustering, refreshes merged canonical embeddings, and skips already-evaluated pairs" do
      dim = vector_def.dimensions
      broader_vector = Array.new(dim) { |i| i == 0 ? 0.68 : (i == 1 ? 0.7332 : 0.0) }
      other_base_vector = Array.new(dim) { |i| i == 3 ? 1.0 : 0.0 }
      other_close_vector = Array.new(dim) { |i| i == 3 ? 0.99 : (i == 4 ? 0.14 : 0.0) }

      canonical =
        Fabricate(:inferred_concept, name: "Community platform migration", status: :active)
      tight_dup = Fabricate(:inferred_concept, name: "Community Migration", status: :candidate)
      broader_dup =
        Fabricate(:inferred_concept, name: "Forum platform data migration", status: :active)

      unrelated_a = Fabricate(:inferred_concept, name: "Plugin Development", status: :active)
      unrelated_b = Fabricate(:inferred_concept, name: "Plugin Hooks", status: :active)

      schema = DiscourseAi::Embeddings::Schema.for(InferredConcept)
      schema.store(canonical, base_vector, "c1")
      schema.store(tight_dup, close_vector, "c2")
      schema.store(broader_dup, broader_vector, "c3")
      schema.store(unrelated_a, other_base_vector, "u1")
      schema.store(unrelated_b, other_close_vector, "u2")

      refreshed_ids = []
      allow_any_instance_of(DiscourseAi::Embeddings::Vector).to receive(
        :gen_bulk_reprensentations,
      ).and_wrap_original do |_method, relation|
        refreshed_ids.concat(relation.pluck(:id))
      end

      evaluated_batches = []
      allow_any_instance_of(DiscourseAi::InferredConcepts::Curator).to receive(
        :deduplicate_cluster,
      ).and_wrap_original do |method, concepts, **kwargs|
        evaluated_batches << concepts.map(&:name)
        ids = concepts.map(&:id)

        if ids.include?(canonical.id) && ids.include?(tight_dup.id)
          response = {
            merges: [{ canonical_id: canonical.id, merge_ids: [tight_dup.id], description: "" }],
            reparents: [],
          }
          DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
            method.call(concepts, **kwargs)
          end
        elsif ids.include?(canonical.id) && ids.include?(broader_dup.id)
          response = {
            merges: [{ canonical_id: canonical.id, merge_ids: [broader_dup.id], description: "" }],
            reparents: [],
          }
          DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
            method.call(concepts, **kwargs)
          end
        else
          DiscourseAi::Completions::Llm.with_prepared_responses([{ merges: [], reparents: [] }]) do
            method.call(concepts, **kwargs)
          end
        end
      end

      stats = curator.deduplicate_clusters!

      expect(stats[:merges_applied]).to eq(2)
      expect(stats[:concepts_retired]).to eq(2)
      expect(tight_dup.reload).to be_retired
      expect(broader_dup.reload).to be_retired
      expect(refreshed_ids).to include(canonical.id)

      unrelated_calls = evaluated_batches.count { |names| names.include?("Plugin Development") }
      expect(unrelated_calls).to eq(1)
    end

    it "includes shared_topics, overlap_ratio, and similarity in related_pairs payload" do
      c1 = Fabricate(:inferred_concept, name: "Platform Migration", status: :active)
      c2 = Fabricate(:inferred_concept, name: "Forum Data Migration", status: :active)

      schema = DiscourseAi::Embeddings::Schema.for(InferredConcept)
      schema.store(c1, base_vector, "p1")
      schema.store(c2, close_vector, "p2")

      3.times do
        topic = Fabricate(:topic)
        InferredConceptTopic.create!(inferred_concept: c1, topic: topic)
        InferredConceptTopic.create!(inferred_concept: c2, topic: topic)
      end

      captured_payloads = []
      fake_bot = instance_double(DiscourseAi::Agents::Bot)
      allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(fake_bot)
      allow(fake_bot).to receive(:reply) do |context|
        captured_payloads << JSON.parse(context.messages.first[:content])
      end

      curator.deduplicate_clusters!(max_passes: 1)

      expect(captured_payloads.size).to eq(1)
      pairs = captured_payloads.first["related_pairs"]
      expect(pairs.size).to eq(1)
      expect(pairs.first["concept_ids"]).to eq([c1.id, c2.id].sort)
      expect(pairs.first["shared_topics"]).to eq(3)
      expect(pairs.first["overlap_ratio"]).to eq(1.0)
      expect(pairs.first["similarity"]).to be > 0.9
    end

    it "continues after per-cluster errors and stops cleanly on CreditLimitExceeded" do
      dim = vector_def.dimensions
      second_vec = Array.new(dim) { |i| i == 3 ? 1.0 : 0.0 }

      c1 = Fabricate(:inferred_concept, name: "Cluster One A", status: :active)
      c2 = Fabricate(:inferred_concept, name: "Cluster One B", status: :active)
      c3 = Fabricate(:inferred_concept, name: "Cluster Two A", status: :active)
      c4 = Fabricate(:inferred_concept, name: "Cluster Two B", status: :active)

      schema = DiscourseAi::Embeddings::Schema.for(InferredConcept)
      schema.store(c1, base_vector, "1a")
      schema.store(c2, close_vector, "1b")
      schema.store(c3, second_vec, "2a")
      schema.store(c4, second_vec, "2b")

      allow(Discourse).to receive(:warn_exception)
      call_index = 0
      allow(DiscourseAi::Agents::Bot).to receive(:as).and_wrap_original do |method, *args, **kw|
        call_index += 1
        raise "transient error" if call_index == 1

        method.call(*args, **kw)
      end

      surviving_merge_response = {
        merges: [{ canonical_id: c1.id, merge_ids: [c2.id], description: "" }],
        reparents: [],
      }

      stats =
        DiscourseAi::Completions::Llm.with_prepared_responses([surviving_merge_response]) do
          curator.deduplicate_clusters!(max_passes: 1)
        end

      expect(Discourse).to have_received(:warn_exception).once
      expect(stats[:merges_applied]).to eq(1)
      expect(stats[:clusters_processed]).to eq(1)
      expect(c2.reload).to be_retired
      expect(c4.reload).to be_active

      allow(LlmCreditAllocation).to receive(:check_credits!).and_raise(
        LlmCreditAllocation::CreditLimitExceeded,
        "limit reached",
      )
      credit_stats = curator.deduplicate_clusters!(max_passes: 1)
      expect(credit_stats[:clusters_processed]).to eq(0)
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
