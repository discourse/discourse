# frozen_string_literal: true

RSpec.describe DiscourseAi::InferredConcepts::Merger do
  subject(:merger) { described_class.new }

  fab!(:vector_def, :cloudflare_embedding_def)
  fab!(:canonical) { Fabricate(:inferred_concept, name: "Kubernetes", status: :active) }
  fab!(:duplicate_one) do
    Fabricate(:inferred_concept, name: "k8s", description: "K8s cluster ops", aliases: ["kube"])
  end
  fab!(:duplicate_two) do
    Fabricate(:inferred_concept, name: "K8s Hosting", status: :candidate, aliases: ["k8s-cloud"])
  end

  let(:sample_vector) { [0.1] * vector_def.dimensions }

  before do
    enable_current_plugin
    SiteSetting.ai_embeddings_selected_model = vector_def.id
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.inferred_concepts_enabled = true
  end

  describe "#merge!" do
    it "losslessly migrates topic and post joins with GREATEST relevance and ORed primary" do
      shared_topic = Fabricate(:topic)
      dup_only_topic = Fabricate(:topic)
      multi_dup_topic = Fabricate(:topic)
      shared_post = Fabricate(:post)
      dup_only_post = Fabricate(:post)

      InferredConceptTopic.create!(
        inferred_concept: canonical,
        topic: shared_topic,
        relevance: 0.6,
        primary: false,
      )
      InferredConceptTopic.create!(
        inferred_concept: duplicate_one,
        topic: shared_topic,
        relevance: 0.9,
        primary: true,
        digest: "abc",
      )
      InferredConceptTopic.create!(
        inferred_concept: duplicate_one,
        topic: dup_only_topic,
        relevance: 0.8,
        primary: true,
      )
      InferredConceptTopic.create!(
        inferred_concept: duplicate_one,
        topic: multi_dup_topic,
        relevance: 0.7,
        primary: false,
      )
      InferredConceptTopic.create!(
        inferred_concept: duplicate_two,
        topic: multi_dup_topic,
        relevance: 0.95,
        primary: true,
      )

      InferredConceptPost.create!(
        inferred_concept: canonical,
        post: shared_post,
        relevance: 0.85,
        primary: false,
      )
      InferredConceptPost.create!(
        inferred_concept: duplicate_one,
        post: shared_post,
        relevance: 0.7,
        primary: true,
      )
      InferredConceptPost.create!(
        inferred_concept: duplicate_two,
        post: dup_only_post,
        relevance: 0.75,
        primary: false,
      )

      DiscourseAi::Embeddings::Schema.for(InferredConcept).store(
        duplicate_one,
        sample_vector,
        "dup1-vec",
      )
      DiscourseAi::Embeddings::Schema.for(InferredConcept).store(
        duplicate_two,
        sample_vector,
        "dup2-vec",
      )

      expect do
        merger.merge!(
          canonical: canonical,
          duplicates: [duplicate_one, duplicate_two],
          description: "Container orchestration with Kubernetes.",
        )
      end.to change { Jobs::GenerateEmbeddings.jobs.size }.by(1)

      expect(canonical.reload.description).to eq("Container orchestration with Kubernetes.")
      expect(canonical.aliases).to contain_exactly("k8s", "kube", "K8s Hosting", "k8s-cloud")

      shared_topic_link =
        InferredConceptTopic.find_by!(inferred_concept: canonical, topic: shared_topic)
      expect(shared_topic_link.relevance).to eq(0.9)
      expect(shared_topic_link.primary).to eq(true)
      expect(shared_topic_link.digest).to eq("abc")

      multi_dup_link =
        InferredConceptTopic.find_by!(inferred_concept: canonical, topic: multi_dup_topic)
      expect(multi_dup_link.relevance).to eq(0.95)
      expect(multi_dup_link.primary).to eq(true)

      expect(
        InferredConceptTopic.find_by!(inferred_concept: canonical, topic: dup_only_topic),
      ).to be_present
      expect(
        InferredConceptPost.find_by!(inferred_concept: canonical, post: shared_post).relevance,
      ).to eq(0.85)
      expect(
        InferredConceptPost.find_by!(inferred_concept: canonical, post: shared_post).primary,
      ).to eq(true)
      expect(
        InferredConceptPost.find_by!(inferred_concept: canonical, post: dup_only_post),
      ).to be_present

      expect(
        InferredConceptTopic.where(inferred_concept_id: [duplicate_one.id, duplicate_two.id]),
      ).to be_empty
      expect(
        InferredConceptPost.where(inferred_concept_id: [duplicate_one.id, duplicate_two.id]),
      ).to be_empty

      expect(duplicate_one.reload).to be_retired
      expect(duplicate_one.aliases).to eq([])
      expect(duplicate_two.reload).to be_retired
      expect(
        DiscourseAi::Embeddings::Schema.for(InferredConcept).find_by_target(duplicate_one),
      ).to be_nil
      expect(
        DiscourseAi::Embeddings::Schema.for(InferredConcept).find_by_target(duplicate_two),
      ).to be_nil

      job_args = Jobs::GenerateEmbeddings.jobs.last["args"].first
      expect(job_args["target_type"]).to eq("InferredConcept")
      expect(job_args["target_id"]).to eq(canonical.id)
    end

    it "reparents children safely without introducing cycles and avoids creating retired duplicates again" do
      grandparent = Fabricate(:inferred_concept, name: "Infrastructure", status: :active)
      child = Fabricate(:inferred_concept, name: "Helm", parent: duplicate_one)
      duplicate_one.update!(parent: grandparent)
      canonical.update!(parent: duplicate_one)

      merger.merge!(canonical: canonical, duplicates: [duplicate_one])

      expect(canonical.reload.parent).to eq(grandparent)
      expect(child.reload.parent).to eq(canonical)
      expect(duplicate_one.reload.parent_id).to be_nil

      assign_fake_provider_to(:ai_default_llm_model)
      topic = Fabricate(:topic)
      Fabricate(:post, topic: topic, post_number: 1, raw: "Using k8s clusters")
      DiscourseAi::Embeddings::Schema.for(Topic).store(topic, sample_vector, "topic-vec")

      response = {
        matches: [],
        proposed_new: [{ name: "k8s", description: "Duplicate", parent_concept_id: 0 }],
      }
      applied =
        DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
          DiscourseAi::InferredConcepts::Manager.new.generate_concepts_from_topic(topic)
        end

      expect(applied).to contain_exactly(canonical)
    end

    it "promotes a candidate canonical concept when absorbing an active duplicate" do
      candidate = Fabricate(:inferred_concept, name: "Container Orchestration", status: :candidate)

      merger.merge!(canonical: candidate, duplicates: [canonical])

      expect(candidate.reload).to be_active
      expect(canonical.reload).to be_retired
    end
  end

  describe "#reparent!" do
    it "updates parent when valid and rejects cycles or retired concepts" do
      child = Fabricate(:inferred_concept, name: "Helm Charts", status: :active)
      retired = Fabricate(:inferred_concept, name: "Legacy K8s", status: :retired)

      expect(merger.reparent!(concept: child, parent: canonical)).to eq(true)
      expect(child.reload.parent).to eq(canonical)

      expect(merger.reparent!(concept: canonical, parent: child)).to eq(false)
      expect(canonical.reload.parent_id).to be_nil

      expect(merger.reparent!(concept: child, parent: retired)).to eq(false)
    end
  end
end
