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
    described_class.reset_inflight!
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
    described_class.reset_inflight!
    DiscourseAi::InferredConcepts::Seeder.reset_status!
  end

  def create_embedded_topic(
    title:,
    word_count: 100,
    created_at: 2.days.ago,
    last_posted_at: created_at
  )
    topic =
      Fabricate(
        :topic,
        title: title,
        word_count: word_count,
        created_at: created_at,
        last_posted_at: last_posted_at,
      )
    Fabricate(:post, topic: topic, post_number: 1, raw: "Body for #{title}")
    vector = [0.5] * vector_def.dimensions
    DiscourseAi::Embeddings::Schema.for(Topic).store(topic, vector, "vec-#{topic.id}")
    topic
  end

  it "prioritizes newest untagged topics first, skips no-match topics on subsequent runs, and picks up newly created topics" do
    SiteSetting.inferred_concepts_backfill_maximum_topics_per_hour = 12
    older_topic =
      create_embedded_topic(
        title: "Older historical topic",
        created_at: 5.days.ago,
        last_posted_at: 5.days.ago,
      )
    newer_topic =
      create_embedded_topic(
        title: "Newer active discussion",
        created_at: 1.day.ago,
        last_posted_at: 1.day.ago,
      )
    short_topic = create_embedded_topic(title: "Short discussion topic", word_count: 10)
    old_topic = create_embedded_topic(title: "Ancient archived topic", created_at: 2.years.ago)
    unembedded_topic = Fabricate(:topic, title: "Topic without vector embedding", word_count: 100)

    # First tick claims the newest eligible topic (newer_topic), which yields 0 matches
    expect do job.execute({}) end.to change { Jobs::BackfillInferredConceptsBatch.jobs.size }.by(1)

    first_args = Jobs::BackfillInferredConceptsBatch.jobs.last["args"].first
    expect(first_args["topic_ids"]).to eq([newer_topic.id])

    DiscourseAi::Decisions.with_canned_answers(c_0: 0.2) do
      Jobs::BackfillInferredConceptsBatch.new.execute(first_args)
    end

    expect(newer_topic.inferred_concepts.reload).to be_empty
    expect(
      TopicCustomField.find_by(
        topic_id: newer_topic.id,
        name: described_class::NO_MATCH_CUSTOM_FIELD,
      ),
    ).to be_present

    # A brand-new topic arrives before the next tick; it must preempt older_topic
    brand_new_topic =
      create_embedded_topic(
        title: "Brand new Kubernetes question",
        created_at: 1.minute.ago,
        last_posted_at: 1.minute.ago,
      )

    expect do job.execute({}) end.to change { Jobs::BackfillInferredConceptsBatch.jobs.size }.by(1)
    second_args = Jobs::BackfillInferredConceptsBatch.jobs.last["args"].first
    expect(second_args["topic_ids"]).to eq([brand_new_topic.id])

    DiscourseAi::Decisions.with_canned_answers(c_0: 0.9) do |canned|
      Jobs::BackfillInferredConceptsBatch.new.execute(second_args)
      expect(canned.calls.sole[:questions].sole.instructions).to include("Kubernetes")
      expect(canned.calls.sole[:questions].sole.instructions).not_to include("Unvetted")
    end

    expect(brand_new_topic.inferred_concepts.reload).to eq([kubernetes])

    # Third tick fills remaining budget with older_topic, skipping short/old/unembedded
    expect do job.execute({}) end.to change { Jobs::BackfillInferredConceptsBatch.jobs.size }.by(1)
    third_args = Jobs::BackfillInferredConceptsBatch.jobs.last["args"].first
    expect(third_args["topic_ids"]).to eq([older_topic.id])

    DiscourseAi::Decisions.with_canned_answers(c_0: 0.9) do
      Jobs::BackfillInferredConceptsBatch.new.execute(third_args)
    end

    expect(older_topic.inferred_concepts.reload).to eq([kubernetes])
    expect(short_topic.inferred_concepts.reload).to be_empty
    expect(old_topic.inferred_concepts.reload).to be_empty
    expect(unembedded_topic.inferred_concepts.reload).to be_empty

    # Fourth tick has nothing left to enqueue
    expect do job.execute({}) end.not_to change { Jobs::BackfillInferredConceptsBatch.jobs.size }
  end

  it "slices large quotas into BATCH_SIZE batch jobs and respects in-flight backpressure" do
    SiteSetting.inferred_concepts_backfill_maximum_topics_per_hour = 240 # 20 per tick
    topics =
      20.times.map do |idx|
        create_embedded_topic(
          title: "Eligible backfill topic #{idx}",
          last_posted_at: idx.minutes.ago,
        )
      end

    expect do job.execute({}) end.to change { Jobs::BackfillInferredConceptsBatch.jobs.size }.by(2)

    enqueued_batches =
      Jobs::BackfillInferredConceptsBatch.jobs.last(2).map { |j| j["args"].first["topic_ids"] }
    expect(enqueued_batches.map(&:size)).to eq([15, 5])
    expect(enqueued_batches.flatten).to eq(topics.map(&:id))

    # All 20 slots are currently in-flight; immediate re-run enqueues nothing
    expect do job.execute({}) end.not_to change { Jobs::BackfillInferredConceptsBatch.jobs.size }

    # After finishing the first 15-topic batch, another tick only refills the 15 freed slots
    DiscourseAi::Decisions.with_canned_answers(c_0: 0.9) do
      Jobs::BackfillInferredConceptsBatch.new.execute(topic_ids: enqueued_batches.first)
    end

    extra_topics =
      20.times.map do |idx|
        create_embedded_topic(
          title: "Subsequent backfill topic #{idx}",
          last_posted_at: Time.zone.now + idx.seconds,
        )
      end

    expect do job.execute({}) end.to change { Jobs::BackfillInferredConceptsBatch.jobs.size }.by(1)
    refill_ids = Jobs::BackfillInferredConceptsBatch.jobs.last["args"].first["topic_ids"]
    expect(refill_ids.size).to eq(15)
    expect(refill_ids & enqueued_batches.second).to be_empty
    expect(extra_topics.map(&:id)).to include(*refill_ids)
  end

  it "skips when credits are exhausted for decision model" do
    decision_model.update!(id: -552)
    SiteSetting.inferred_concepts_match_decision_model = decision_model.id
    Fabricate(:decision_model_credit_allocation, decision_model: decision_model, daily_credits: 5)
    DecisionModelCreditDailyUsage.increment_usage!(decision_model, 5)
    create_embedded_topic(title: "Blocked by credits discussion")

    expect do job.execute({}) end.not_to change { Jobs::BackfillInferredConceptsBatch.jobs.size }
  end

  it "skips when disabled, budget is 0, no active concepts exist, or seeding is in progress" do
    create_embedded_topic(title: "Skipped backfill discussion")

    SiteSetting.inferred_concepts_backfill_maximum_topics_per_hour = 0
    expect do job.execute({}) end.not_to change { Jobs::BackfillInferredConceptsBatch.jobs.size }

    SiteSetting.inferred_concepts_backfill_maximum_topics_per_hour = 60
    DiscourseAi::InferredConcepts::Seeder.mark_queued!
    expect do job.execute({}) end.not_to change { Jobs::BackfillInferredConceptsBatch.jobs.size }

    DiscourseAi::InferredConcepts::Seeder.reset_status!
    kubernetes.update!(status: :candidate)
    expect do job.execute({}) end.not_to change { Jobs::BackfillInferredConceptsBatch.jobs.size }
  end

  it "resumes stalled seeding runs even when backfill budget is 0 and no active concepts exist" do
    SiteSetting.inferred_concepts_backfill_maximum_topics_per_hour = 0
    kubernetes.update!(status: :candidate)

    queued = DiscourseAi::InferredConcepts::Seeder.mark_queued!
    stalled_time = (DiscourseAi::InferredConcepts::Seeder::WAVE_STALE_AFTER + 1.minute).ago.iso8601
    Discourse.redis.set(
      DiscourseAi::InferredConcepts::Seeder::STATE_KEY,
      queued.merge("status" => "running", "updated_at" => stalled_time).to_json,
    )

    expect do job.execute({}) end.to change { Jobs::SeedInferredConcepts.jobs.size }.by(1)
    expect(Jobs::SeedInferredConcepts.jobs.last["args"].first["run_id"]).to eq(queued["run_id"])
  end
end
