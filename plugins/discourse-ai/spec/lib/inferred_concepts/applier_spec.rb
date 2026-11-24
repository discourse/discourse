# frozen_string_literal: true

RSpec.describe DiscourseAi::InferredConcepts::Applier do
  subject(:applier) { described_class.new }

  fab!(:vector_def, :cloudflare_embedding_def)
  fab!(:topic) { Fabricate(:topic, title: "Ruby Programming Tutorial") }
  fab!(:post) { Fabricate(:post, raw: "This post is about advanced testing techniques") }
  fab!(:user) { Fabricate(:user, username: "dev_user") }
  fab!(:concept1) { Fabricate(:inferred_concept, name: "programming") }
  fab!(:concept2) { Fabricate(:inferred_concept, name: "testing") }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_embeddings_selected_model = vector_def.id
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.inferred_concepts_enabled = true
    post.update!(user: user)

    vector = [0.1] * vector_def.dimensions
    DiscourseAi::Embeddings::Schema.for(Topic).store(topic, vector, "topic-vec")
    DiscourseAi::Embeddings::Schema.for(Post).store(post, vector, "post-vec")
  end

  describe "#apply_to_topic" do
    it "does nothing for blank topic or concepts and is idempotent" do
      expect { applier.apply_to_topic(nil, [concept1]) }.not_to raise_error
      expect { applier.apply_to_topic(topic, []) }.not_to raise_error

      applier.apply_to_topic(topic, [concept1, concept2])
      applier.apply_to_topic(topic, [concept1])

      expect(topic.inferred_concepts).to contain_exactly(concept1, concept2)
    end
  end

  describe "#apply_to_post" do
    it "associates concepts idempotently" do
      applier.apply_to_post(post, [concept1, concept2])
      applier.apply_to_post(post, [concept2])

      expect(post.inferred_concepts).to contain_exactly(concept1, concept2)
    end
  end

  describe "#apply_matches_to_topic" do
    it "upserts relevance, primary, and digest and removes stale associations on re-classification" do
      applier.apply_matches_to_topic(
        topic,
        [
          { concept: concept1, relevance: 0.9, primary: true },
          { concept: concept2, relevance: 0.6, primary: false },
        ],
        digest: "digest-1",
      )

      link = InferredConceptTopic.find_by(topic_id: topic.id, inferred_concept_id: concept1.id)
      expect(link.relevance).to eq(0.9)
      expect(link.primary).to eq(true)
      expect(link.digest).to eq("digest-1")

      applier.apply_matches_to_topic(
        topic,
        [{ concept: concept2, relevance: 0.95, primary: true }],
        digest: "digest-2",
      )

      expect(topic.inferred_concepts).to contain_exactly(concept2)
      updated = InferredConceptTopic.find_by(topic_id: topic.id, inferred_concept_id: concept2.id)
      expect(updated.relevance).to eq(0.95)
      expect(updated.primary).to eq(true)
      expect(updated.digest).to eq("digest-2")
    end
  end

  describe "#topic_content_for_analysis" do
    it "returns empty string for blank topic" do
      expect(applier.topic_content_for_analysis(nil)).to eq("")
    end

    it "extracts title, category, regular posts up to 10, and truncates long content" do
      category = Fabricate(:category, name: "Engineering")
      topic.update!(category: category)
      12.times do |i|
        Fabricate(:post, topic: topic, post_number: i + 1, raw: "Post #{i + 1}", user: user)
      end
      Fabricate(
        :post,
        topic: topic,
        post_number: 13,
        post_type: Post.types[:whisper],
        raw: "Secret whisper",
        user: user,
      )

      content = applier.topic_content_for_analysis(topic)

      expect(content).to include(topic.title)
      expect(content).to include("Category: Engineering")
      expect(content).to include("10) dev_user: Post 10")
      expect(content).not_to include("11) dev_user: Post 11")
      expect(content).not_to include("Secret whisper")

      stub_const(described_class, :MAX_CONTENT_CHARS, 40) do
        expect(applier.topic_content_for_analysis(topic).length).to eq(40)
      end
    end
  end

  describe "#post_content_for_analysis" do
    it "returns empty string for blank post and includes topic context" do
      expect(applier.post_content_for_analysis(nil)).to eq("")

      content = applier.post_content_for_analysis(post)
      expect(content).to include(post.topic.title)
      expect(content).to include(post.raw)
      expect(content).to include(user.username)
    end
  end

  describe "#match_existing_concepts" do
    it "matches concepts via ConceptMatcher, stores metadata, and skips unchanged digests" do
      Fabricate(:post, topic: topic, post_number: 1, raw: "Ruby programming guide", user: user)
      response = { matches: [{ concept_id: concept1.id, relevance: 0.92, primary: true }] }

      matched =
        DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
          applier.match_existing_concepts(topic)
        end

      expect(matched).to eq([concept1])
      expect(topic.inferred_concepts).to contain_exactly(concept1)

      # Unchanged digest returns existing concepts without calling the LLM again
      expect(applier.match_existing_concepts(topic)).to contain_exactly(concept1)
    end
  end

  describe "#match_existing_concepts_for_post" do
    it "matches concepts for a post and persists relevance" do
      response = { matches: [{ concept_id: concept2.id, relevance: 0.85, primary: true }] }

      matched =
        DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
          applier.match_existing_concepts_for_post(post)
        end

      expect(matched).to eq([concept2])
      link = InferredConceptPost.find_by(post_id: post.id, inferred_concept_id: concept2.id)
      expect(link.relevance).to eq(0.85)
    end
  end

  describe "#match_concepts_to_content" do
    it "returns empty array for blank content or concept list" do
      expect(applier.match_concepts_to_content("", ["concept1"])).to eq([])
      expect(applier.match_concepts_to_content("content", [])).to eq([])
    end

    it "matches both concept names and InferredConcept records" do
      response = { matches: [{ concept_id: concept1.id, relevance: 0.9, primary: true }] }

      result =
        DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
          applier.match_concepts_to_content("Ruby programming", %w[programming testing])
        end

      expect(result).to eq(["programming"])
    end
  end
end
