# frozen_string_literal: true

RSpec.describe DiscourseAi::InferredConcepts::Finder do
  subject(:finder) { described_class.new }

  fab!(:vector_def, :cloudflare_embedding_def)
  fab!(:topic) { Fabricate(:topic, posts_count: 5, views: 200, like_count: 15) }
  fab!(:post) { Fabricate(:post, like_count: 10) }
  fab!(:concept1) { Fabricate(:inferred_concept, name: "programming") }
  fab!(:concept2) { Fabricate(:inferred_concept, name: "testing") }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_embeddings_selected_model = vector_def.id
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.inferred_concepts_enabled = true
  end

  describe "#identify_concepts" do
    it "returns empty array for blank content" do
      expect(finder.identify_concepts("")).to eq([])
      expect(finder.identify_concepts(nil)).to eq([])
    end

    it "combines matched existing concepts and proposed new concepts" do
      query = "This is about Ruby programming and metaprogramming"
      EmbeddingsGenerationStubs.cloudflare_service(query, [0.1] * vector_def.dimensions)
      response = {
        matches: [{ concept_id: concept1.id, relevance: 0.9, primary: true }],
        proposed_new: [
          { name: "Metaprogramming", description: "Dynamic Ruby features", parent_concept_id: 0 },
        ],
      }

      result =
        DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
          finder.identify_concepts(query)
        end

      expect(result).to eq(%w[programming Metaprogramming])
    end
  end

  describe "#create_or_find_concepts" do
    it "returns empty array for blank concept names" do
      expect(finder.create_or_find_concepts([])).to eq([])
      expect(finder.create_or_find_concepts(nil)).to eq([])
    end

    it "reuses concepts matched by name or alias and creates missing ones" do
      concept1.update!(aliases: ["coding"])

      result = finder.create_or_find_concepts(%w[coding testing new_concept])

      expect(result.map(&:name)).to eq(%w[programming testing new_concept])
      expect(result.first).to eq(concept1)
      expect(result.second).to eq(concept2)
    end
  end

  describe "#find_candidate_topics" do
    fab!(:good_topic) { Fabricate(:topic, posts_count: 6, views: 150, like_count: 12) }
    fab!(:bad_topic) { Fabricate(:topic, posts_count: 2, views: 50, like_count: 2) }
    fab!(:topic_with_concepts) do
      t = Fabricate(:topic, posts_count: 8, views: 200, like_count: 20)
      t.inferred_concepts << concept1
      t
    end

    it "finds topics meeting minimum criteria without already-tagged topics" do
      candidates = finder.find_candidate_topics(min_posts: 5, min_views: 100, min_likes: 10)

      expect(candidates).to include(good_topic)
      expect(candidates).not_to include(bad_topic)
      expect(candidates).not_to include(topic_with_concepts)
    end

    it "filters by category_ids and created_after" do
      category = Fabricate(:category)
      topic_in_category =
        Fabricate(:topic, category: category, posts_count: 6, views: 150, like_count: 12)
      old_topic =
        Fabricate(:topic, posts_count: 6, views: 150, like_count: 12, created_at: 45.days.ago)

      expect(finder.find_candidate_topics(category_ids: [category.id])).to contain_exactly(
        topic_in_category,
      )
      expect(finder.find_candidate_topics(created_after: 30.days.ago)).not_to include(old_topic)
    end
  end

  describe "#find_candidate_posts" do
    fab!(:good_post) { Fabricate(:post, like_count: 8, post_number: 2) }
    fab!(:bad_post) { Fabricate(:post, like_count: 2, post_number: 2) }
    fab!(:first_post) { Fabricate(:post, like_count: 10, post_number: 1) }

    it "finds non-first posts meeting criteria" do
      candidates = finder.find_candidate_posts(min_likes: 5)

      expect(candidates).to include(good_post)
      expect(candidates).not_to include(bad_post, first_post)
    end
  end
end
