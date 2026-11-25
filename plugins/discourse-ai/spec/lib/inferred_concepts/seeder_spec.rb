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
  end

  describe ".seeding?" do
    it "treats fresh queued/running states as active and stale ones as inactive" do
      described_class.mark_queued!
      expect(described_class).to be_seeding

      stale_time = (described_class::STALE_AFTER + 5.minutes).ago.iso8601
      PluginStore.set(
        described_class::PLUGIN_STORE_NAMESPACE,
        described_class::STATE_KEY,
        { "status" => "running", "updated_at" => stale_time },
      )

      expect(described_class).not_to be_seeding
      expect(described_class.status).to be_nil
    end
  end
end
