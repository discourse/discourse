# frozen_string_literal: true

RSpec.describe DiscourseAi::InferredConcepts::Seeder do
  subject(:seeder) { described_class.new }

  fab!(:vector_def, :cloudflare_embedding_def)

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_embeddings_selected_model = vector_def.id
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.inferred_concepts_enabled = true
    described_class.reset_status!
  end

  after { described_class.reset_status! }

  describe "#select_seed_topics" do
    fab!(:category_a, :category)
    fab!(:category_b, :category)

    it "selects top topics stratified across categories, skips ineligible ones, and tops up from older topics" do
      a_top =
        Fabricate(
          :topic,
          category: category_a,
          like_count: 50,
          posts_count: 10,
          views: 500,
          word_count: 120,
        )
      a_second =
        Fabricate(
          :topic,
          category: category_a,
          like_count: 20,
          posts_count: 5,
          views: 200,
          word_count: 100,
        )
      b_top =
        Fabricate(
          :topic,
          category: category_b,
          like_count: 30,
          posts_count: 6,
          views: 300,
          word_count: 120,
        )
      old_top =
        Fabricate(
          :topic,
          category: category_b,
          like_count: 40,
          posts_count: 8,
          views: 400,
          word_count: 120,
          created_at: 4.years.ago,
        )

      short_topic = Fabricate(:topic, category: category_a, like_count: 99, word_count: 10)
      pm_topic = Fabricate(:private_message_topic, like_count: 99, word_count: 200)
      deleted_topic =
        Fabricate(
          :topic,
          category: category_a,
          like_count: 99,
          word_count: 200,
          deleted_at: 1.day.ago,
        )
      already_classified = Fabricate(:topic, category: category_a, like_count: 99, word_count: 200)
      InferredConceptTopic.create!(
        inferred_concept: Fabricate(:inferred_concept),
        topic: already_classified,
      )

      selected_recent = seeder.select_seed_topics(limit: 2)
      expect(selected_recent).to eq([a_top.id, b_top.id])

      selected_with_top_up = seeder.select_seed_topics(limit: 4)
      expect(selected_with_top_up).to eq([a_top.id, b_top.id, a_second.id, old_top.id])
      expect(selected_with_top_up).not_to include(
        short_topic.id,
        pm_topic.id,
        deleted_topic.id,
        already_classified.id,
      )
    end
  end

  describe "#seed!" do
    it "classifies seed topics, embeds created concepts, runs curation, and records completion status" do
      category = Fabricate(:category)
      topic =
        Fabricate(
          :topic,
          title: "Deploying PostgreSQL with pgvector",
          category: category,
          word_count: 120,
          like_count: 25,
          posts_count: 5,
          views: 250,
        )
      Fabricate(:post, topic: topic, post_number: 1, raw: "Detailed guide on pgvector indexing.")

      vector = [0.1] * vector_def.dimensions
      DiscourseAi::Embeddings::Schema.for(Topic).store(topic, vector, "topic-vec")

      allow_any_instance_of(DiscourseAi::Embeddings::Vector).to receive(
        :gen_bulk_reprensentations,
      ).and_wrap_original do |_method, relation|
        relation.each do |concept|
          DiscourseAi::Embeddings::Schema.for(InferredConcept).store(concept, vector, "concept-vec")
        end
      end

      curator =
        instance_double(DiscourseAi::InferredConcepts::Curator, curate!: { merged_clusters: 0 })
      allow(DiscourseAi::InferredConcepts::Curator).to receive(:new).and_return(curator)

      llm_response = {
        matches: [],
        proposed_new: [
          {
            name: "pgvector",
            description: "Vector similarity search in PostgreSQL",
            parent_concept_id: nil,
          },
        ],
      }

      state =
        DiscourseAi::Completions::Llm.with_prepared_responses([llm_response]) do
          seeder.seed!(limit: 10)
        end

      expect(state["status"]).to eq("completed")
      expect(state["processed"]).to eq(1)
      expect(state["total"]).to eq(1)
      expect(state["concepts_created"]).to eq(1)
      expect(InferredConcept.find_by(name: "pgvector")).to be_present
      expect(curator).to have_received(:curate!)
      expect(described_class.status["status"]).to eq("completed")
      expect(described_class).not_to be_seeding
    end

    it "processes waves in parallel, embeds concepts between waves, coalesces duplicates, and runs intermediate curation" do
      category_a = Fabricate(:category)
      category_b = Fabricate(:category)
      vector = [0.1] * vector_def.dimensions

      topics =
        [
          ["Wave one alpha topic", category_a, 40],
          ["Wave one beta topic", category_b, 35],
          ["Wave two gamma topic", category_a, 20],
          ["Wave two delta topic", category_b, 15],
        ].map do |title, category, likes|
          topic =
            Fabricate(
              :topic,
              title: title,
              category: category,
              word_count: 120,
              like_count: likes,
              posts_count: 5,
              views: 250,
            )
          Fabricate(:post, topic: topic, post_number: 1, raw: "Detailed discussion about #{title}.")
          DiscourseAi::Embeddings::Schema.for(Topic).store(topic, vector, "topic-vec-#{topic.id}")
          topic
        end

      allow_any_instance_of(DiscourseAi::Embeddings::Vector).to receive(
        :gen_bulk_reprensentations,
      ).and_wrap_original do |_method, relation|
        relation.each do |concept|
          DiscourseAi::Embeddings::Schema.for(InferredConcept).store(concept, vector, "concept-vec")
        end
      end

      curator =
        instance_double(DiscourseAi::InferredConcepts::Curator, curate!: { merged_clusters: 0 })
      allow(DiscourseAi::InferredConcepts::Curator).to receive(:new).and_return(curator)

      mutex = Mutex.new
      observed_candidates = {}

      allow_any_instance_of(DiscourseAi::InferredConcepts::Classifier).to receive(
        :classify,
      ) do |_instance, content, candidates:, **_opts|
        mutex.synchronize { observed_candidates[content] = candidates.map(&:name) }

        if content.include?("Wave one")
          {
            matches: [],
            proposed_new: [
              {
                name: "ParallelTheme",
                description: "Theme proposed concurrently in wave one",
                parent_concept_id: nil,
              },
            ],
          }
        else
          {
            matches: [],
            proposed_new: [
              {
                name: "SecondWaveTheme",
                description: "Theme proposed in wave two",
                parent_concept_id: nil,
              },
            ],
          }
        end
      end

      wave_seeder = described_class.new(concurrency: 2, wave_size: 2, curate_every: 2)
      state = wave_seeder.seed!(limit: 4)

      expect(state["status"]).to eq("completed")
      expect(state["processed"]).to eq(4)
      expect(state["total"]).to eq(4)
      expect(InferredConcept.where(name: "ParallelTheme").count).to eq(1)
      expect(InferredConcept.find_by(name: "SecondWaveTheme")).to be_present
      expect(curator).to have_received(:curate!).twice

      wave_two_contents =
        observed_candidates.select { |content, _| content.include?("Wave two") }.values
      expect(wave_two_contents.size).to eq(2)
      expect(wave_two_contents).to all(include("ParallelTheme"))
      topics.each { |topic| expect(topic.inferred_concepts.reload).not_to be_empty }
    end

    it "stops on CreditLimitExceeded, persists prior waves, and records a failed state" do
      category = Fabricate(:category)
      vector = [0.1] * vector_def.dimensions

      topic1 =
        Fabricate(
          :topic,
          title: "First credit-safe discussion",
          category: category,
          word_count: 120,
          like_count: 30,
          posts_count: 5,
          views: 250,
        )
      topic2 =
        Fabricate(
          :topic,
          title: "Second credit-blocked discussion",
          category: category,
          word_count: 120,
          like_count: 10,
          posts_count: 5,
          views: 200,
        )
      [topic1, topic2].each do |topic|
        Fabricate(:post, topic: topic, post_number: 1, raw: "Content for #{topic.title}")
        DiscourseAi::Embeddings::Schema.for(Topic).store(topic, vector, "topic-vec-#{topic.id}")
      end

      allow_any_instance_of(DiscourseAi::Embeddings::Vector).to receive(
        :gen_bulk_reprensentations,
      ).and_wrap_original do |_method, relation|
        relation.each do |concept|
          DiscourseAi::Embeddings::Schema.for(InferredConcept).store(concept, vector, "concept-vec")
        end
      end

      curator =
        instance_double(DiscourseAi::InferredConcepts::Curator, curate!: { merged_clusters: 0 })
      allow(DiscourseAi::InferredConcepts::Curator).to receive(:new).and_return(curator)

      allow_any_instance_of(DiscourseAi::InferredConcepts::Classifier).to receive(
        :classify,
      ) do |_instance, content, **_opts|
        if content.include?("Second credit-blocked")
          raise LlmCreditAllocation::CreditLimitExceeded, "Limit hit"
        end

        {
          matches: [],
          proposed_new: [
            {
              name: "SurvivingConcept",
              description: "Created before limit was hit",
              parent_concept_id: nil,
            },
          ],
        }
      end

      wave_seeder = described_class.new(concurrency: 1, wave_size: 1)
      state = wave_seeder.seed!(limit: 2)

      expect(state["status"]).to eq("failed")
      expect(state["error"]).to eq("Limit hit")
      expect(state["processed"]).to eq(1)
      expect(state["total"]).to eq(2)
      expect(InferredConcept.find_by(name: "SurvivingConcept")).to be_present
      expect(curator).to have_received(:curate!).once
    end

    it "fails cleanly when no LLM is configured for the generate agent" do
      SiteSetting.ai_default_llm_model = ""

      state = seeder.seed!(limit: 5)

      expect(state["status"]).to eq("failed")
      expect(state["error"]).to eq(I18n.t("discourse_ai.errors.no_default_llm"))
      expect(described_class).not_to be_seeding
    end
  end

  describe ".seeding?" do
    it "treats fresh queued/running states as active and stale ones as inactive" do
      described_class.mark_queued!
      expect(described_class).to be_seeding

      stale_time = (described_class::STALE_AFTER + 5.minutes).ago.iso8601
      Discourse.redis.set(
        described_class::STATE_KEY,
        { "status" => "running", "updated_at" => stale_time }.to_json,
      )

      expect(described_class).not_to be_seeding
      expect(described_class.status).to be_nil
    end
  end
end
