# frozen_string_literal: true

RSpec.describe Jobs::BackfillInferredConceptsBatch do
  subject(:job) { described_class.new }

  fab!(:vector_def, :cloudflare_embedding_def)
  fab!(:decision_model)
  fab!(:kubernetes) do
    Fabricate(:inferred_concept, name: "Kubernetes", description: "Containers", status: :active)
  end
  fab!(:candidate_concept) { Fabricate(:inferred_concept, name: "Unvetted", status: :candidate) }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_embeddings_selected_model = vector_def.id
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.inferred_concepts_enabled = true
    SiteSetting.inferred_concepts_match_decision_model = decision_model.id
    Jobs::InferredConceptsBackfill.reset_inflight!
    DiscourseAi::InferredConcepts::Seeder.reset_status!

    vector = [0.5] * vector_def.dimensions
    DiscourseAi::Embeddings::Schema.for(InferredConcept).store(kubernetes, vector, "k8s-vec")
    DiscourseAi::Embeddings::Schema.for(InferredConcept).store(
      candidate_concept,
      vector,
      "cand-vec",
    )
  end

  after do
    Jobs::InferredConceptsBackfill.reset_inflight!
    DiscourseAi::InferredConcepts::Seeder.reset_status!
  end

  def create_embedded_topic(title:)
    topic = Fabricate(:topic, title: title, word_count: 120)
    Fabricate(:post, topic: topic, post_number: 1, raw: "Detailed discussion about #{title}")
    vector = [0.5] * vector_def.dimensions
    DiscourseAi::Embeddings::Schema.for(Topic).store(topic, vector, "vec-#{topic.id}")
    topic
  end

  it "processes topics in parallel using DecisionMatcher and releases in-flight claims" do
    topic1 = create_embedded_topic(title: "Kubernetes Upgrade Guide One")
    topic2 = create_embedded_topic(title: "Kubernetes Upgrade Guide Two")
    topic3 = create_embedded_topic(title: "Kubernetes Upgrade Guide Three")

    expires_at = Time.now.to_f + 600
    [topic1, topic2, topic3].each do |topic|
      Discourse.redis.zadd(Jobs::InferredConceptsBackfill::INFLIGHT_KEY, expires_at, topic.id.to_s)
    end

    DiscourseAi::Decisions.with_canned_answers(c_0: 0.9) do
      job.execute(topic_ids: [topic1.id, topic2.id, topic3.id], concurrency: 2)
    end

    [topic1, topic2, topic3].each do |topic|
      expect(topic.inferred_concepts.reload).to eq([kubernetes])
    end
    expect(Discourse.redis.zrange(Jobs::InferredConceptsBackfill::INFLIGHT_KEY, 0, -1)).to be_empty
  end

  it "falls back to the LLM Classifier when no decision model is configured" do
    SiteSetting.inferred_concepts_match_decision_model = ""
    topic = create_embedded_topic(title: "Kubernetes Nodes Architecture")

    llm_response = { matches: [{ concept_id: kubernetes.id, relevance: 0.88, primary: true }] }

    DiscourseAi::Completions::Llm.with_prepared_responses([llm_response]) do
      job.execute(topic_ids: [topic.id], concurrency: 1)
    end

    expect(topic.inferred_concepts.reload).to eq([kubernetes])
  end

  it "marks clean 0-match topics and removes the marker if concepts are later applied" do
    topic = create_embedded_topic(title: "Offtopic Weekend Recipes Discussion")

    DiscourseAi::Decisions.with_canned_answers(c_0: 0.1) do
      job.execute(topic_ids: [topic.id], concurrency: 1)
    end

    expect(topic.inferred_concepts.reload).to be_empty
    expect(
      TopicCustomField.find_by(
        topic_id: topic.id,
        name: DiscourseAi::InferredConcepts::Applier::NO_MATCH_CUSTOM_FIELD,
      ),
    ).to be_present

    DiscourseAi::InferredConcepts::Applier.new.apply_to_topic(topic, [kubernetes])
    expect(
      TopicCustomField.find_by(
        topic_id: topic.id,
        name: DiscourseAi::InferredConcepts::Applier::NO_MATCH_CUSTOM_FIELD,
      ),
    ).to be_nil
  end

  it "halts after MAX_CONSECUTIVE_FAILURES without marking failed topics as no_match" do
    topics =
      4.times.map { |idx| create_embedded_topic(title: "Failing concept attribution #{idx}") }

    call_count = 0
    allow_any_instance_of(DiscourseAi::InferredConcepts::DecisionMatcher).to receive(:match) do
      call_count += 1
      { matches: [], all_refused: true }
    end

    allow(Discourse).to receive(:warn_exception)
    job.execute(topic_ids: topics.map(&:id), concurrency: 1)

    expect(call_count).to eq(described_class::MAX_CONSECUTIVE_FAILURES)
    expect(Discourse).to have_received(:warn_exception).exactly(3).times
    expect(
      TopicCustomField.where(
        topic_id: topics.map(&:id),
        name: DiscourseAi::InferredConcepts::Applier::NO_MATCH_CUSTOM_FIELD,
      ),
    ).to be_empty
  end

  it "halts cleanly on CreditLimitExceeded without marking topics as no_match" do
    topics = 2.times.map { |idx| create_embedded_topic(title: "Credit limited topic #{idx}") }

    allow_any_instance_of(DiscourseAi::InferredConcepts::DecisionMatcher).to receive(
      :match,
    ).and_raise(DiscourseAi::Decisions::CreditLimitExceeded, "Quota exhausted")

    job.execute(topic_ids: topics.map(&:id), concurrency: 1)

    expect(
      TopicCustomField.where(
        topic_id: topics.map(&:id),
        name: DiscourseAi::InferredConcepts::Applier::NO_MATCH_CUSTOM_FIELD,
      ),
    ).to be_empty
  end
end
