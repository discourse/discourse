# frozen_string_literal: true

RSpec.describe Jobs::InferredConceptsBackfill do
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
    SiteSetting.inferred_concepts_backfill_maximum_topics_per_hour = 60
    SiteSetting.inferred_concepts_backfill_max_age_days = 365
    SiteSetting.inferred_concepts_backfill_minimum_word_count = 50
    described_class.reset_cursor!
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
    described_class.reset_cursor!
    DiscourseAi::InferredConcepts::Seeder.reset_status!
  end

  def create_embedded_topic(title:, word_count: 100, created_at: 2.days.ago)
    topic = Fabricate(:topic, title: title, word_count: word_count, created_at: created_at)
    Fabricate(:post, topic: topic, post_number: 1, raw: "Body for #{title}")
    vector = [0.5] * vector_def.dimensions
    DiscourseAi::Embeddings::Schema.for(Topic).store(topic, vector, "vec-#{topic.id}")
    topic
  end

  it "backfills topics with stored embeddings using active concepts only and advances cursor past 0-match topics" do
    SiteSetting.inferred_concepts_backfill_maximum_topics_per_hour = 12
    matched_topic = create_embedded_topic(title: "Kubernetes Upgrade Guide")
    unmatched_topic = create_embedded_topic(title: "General Offtopic Chat")
    short_topic = create_embedded_topic(title: "Short discussion topic", word_count: 10)
    old_topic = create_embedded_topic(title: "Ancient archived topic", created_at: 2.years.ago)
    unembedded_topic = Fabricate(:topic, title: "Topic without vector embedding", word_count: 100)

    # First run processes newest eligible topic (unmatched_topic) and gets below-threshold score
    DiscourseAi::Decisions.with_canned_answers(c_0: 0.2) do |canned|
      job.execute({})

      expect(canned.calls.size).to eq(1)
      expect(canned.calls.sole[:questions].sole.instructions).to include("Kubernetes")
      expect(canned.calls.sole[:questions].sole.instructions).not_to include("Unvetted")
    end

    expect(unmatched_topic.inferred_concepts.reload).to be_empty

    # Second run skips unmatched_topic via cursor and matches matched_topic
    DiscourseAi::Decisions.with_canned_answers(c_0: 0.9) do |canned|
      job.execute({})

      expect(canned.calls.size).to eq(1)
      expect(canned.calls.sole[:state]).to include("Kubernetes Upgrade Guide")
    end

    expect(matched_topic.inferred_concepts.reload).to eq([kubernetes])
    expect(short_topic.inferred_concepts.reload).to be_empty
    expect(old_topic.inferred_concepts.reload).to be_empty
    expect(unembedded_topic.inferred_concepts.reload).to be_empty

    # Third run finds no remaining eligible topics
    DiscourseAi::Decisions.with_canned_answers(c_0: 0.9) do |canned|
      job.execute({})
      expect(canned.calls).to be_empty
    end
  end

  it "falls back to the LLM Classifier when no decision model is configured" do
    SiteSetting.inferred_concepts_match_decision_model = ""
    topic = create_embedded_topic(title: "Kubernetes Nodes")

    llm_response = { matches: [{ concept_id: kubernetes.id, relevance: 0.88, primary: true }] }

    DiscourseAi::Completions::Llm.with_prepared_responses([llm_response]) { job.execute({}) }

    expect(topic.inferred_concepts.reload).to eq([kubernetes])
  end

  it "stops and preserves cursor position when decision model credits are exhausted" do
    decision_model.update!(id: -552)
    Fabricate(:decision_model_credit_allocation, decision_model: decision_model, daily_credits: 5)
    DecisionModelCreditDailyUsage.increment_usage!(decision_model, 5)
    topic = create_embedded_topic(title: "Blocked by credits")

    DiscourseAi::Decisions.with_canned_answers(c_0: 0.9) do |canned|
      job.execute({})
      expect(canned.calls).to be_empty
    end

    expect(topic.inferred_concepts.reload).to be_empty
  end

  it "halts after MAX_CONSECUTIVE_FAILURES without advancing cursor past failed topics" do
    SiteSetting.inferred_concepts_backfill_maximum_topics_per_hour = 120
    create_embedded_topic(title: "Failing discussion one")
    create_embedded_topic(title: "Failing discussion two")
    create_embedded_topic(title: "Failing discussion three")
    fourth = create_embedded_topic(title: "Never reached discussion topic")

    allow_any_instance_of(DiscourseAi::InferredConcepts::Applier).to receive(
      :match_existing_concepts,
    ).and_raise(DiscourseAi::Decisions::RequestFailed.new("Boom"))

    job.execute({})

    expect(fourth.inferred_concepts.reload).to be_empty
    expect(
      PluginStore.get(described_class::PLUGIN_STORE_NAMESPACE, described_class::CURSOR_KEY),
    ).to be_nil
  end

  it "skips when disabled, budget is 0, no active concepts exist, or seeding is in progress" do
    topic = create_embedded_topic(title: "Skipped backfill discussion")

    SiteSetting.inferred_concepts_backfill_maximum_topics_per_hour = 0
    job.execute({})
    expect(topic.inferred_concepts.reload).to be_empty

    SiteSetting.inferred_concepts_backfill_maximum_topics_per_hour = 60
    DiscourseAi::InferredConcepts::Seeder.mark_queued!
    job.execute({})
    expect(topic.inferred_concepts.reload).to be_empty

    DiscourseAi::InferredConcepts::Seeder.reset_status!
    kubernetes.update!(status: :candidate)
    job.execute({})
    expect(topic.inferred_concepts.reload).to be_empty
  end
end
