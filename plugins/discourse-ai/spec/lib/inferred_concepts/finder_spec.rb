# frozen_string_literal: true

RSpec.describe DiscourseAi::InferredConcepts::Finder do
  subject(:finder) { described_class.new }

  fab!(:topic) { Fabricate(:topic, posts_count: 5, views: 200, like_count: 15) }
  fab!(:post) { Fabricate(:post, like_count: 10) }
  fab!(:concept1) { Fabricate(:inferred_concept, name: "programming") }
  fab!(:concept2) { Fabricate(:inferred_concept, name: "testing") }
  fab!(:llm_model, :fake_model)

  before do
    enable_current_plugin
    SiteSetting.inferred_concepts_generate_persona = -1
    SiteSetting.inferred_concepts_deduplicate_persona = -1
    SiteSetting.inferred_concepts_enabled = true
  end

  describe "#identify_concepts" do
    it "returns empty array for blank content" do
      expect(finder.identify_concepts("")).to eq([])
      expect(finder.identify_concepts(nil)).to eq([])
    end

    it "uses ConceptFinder persona to identify concepts" do
      content = "This is about Ruby programming and testing"
      structured_output_double = instance_double("DiscourseAi::Completions::StructuredOutput")

      # Mock the persona and bot interaction
      persona_class_double = double("PersonaClass") # rubocop:disable RSpec/VerifiedDoubles
      persona_instance_double = double("PersonaInstance") # rubocop:disable RSpec/VerifiedDoubles
      bot_double = instance_double("DiscourseAi::Personas::Bot")

      allow(AiPersona).to receive(:all_personas).and_return([persona_class_double])
      allow(persona_class_double).to receive(:id).and_return(
        SiteSetting.inferred_concepts_generate_persona.to_i,
      )
      allow(persona_class_double).to receive(:new).and_return(persona_instance_double)
      allow(persona_instance_double).to receive(:class).and_return(persona_class_double)
      allow(persona_class_double).to receive(:default_llm_id).and_return(llm_model.id)
      allow(LlmModel).to receive(:find).with(llm_model.id).and_return(llm_model)
      allow(DiscourseAi::Personas::Bot).to receive(:as).and_return(bot_double)
      allow(bot_double).to receive(:reply).and_yield(
        structured_output_double,
        nil,
        :structured_output,
      )
      allow(structured_output_double).to receive(:read_buffered_property).with(
        :concepts,
      ).and_return(%w[ruby programming testing])

      result = finder.identify_concepts(content)
      expect(result).to eq(%w[ruby programming testing])
    end

    it "handles no structured output gracefully" do
      content = "Test content"

      persona_class_double = double("PersonaClass") # rubocop:disable RSpec/VerifiedDoubles
      persona_instance_double = double("PersonaInstance") # rubocop:disable RSpec/VerifiedDoubles
      bot_double = instance_double("DiscourseAi::Personas::Bot")

      allow(AiPersona).to receive(:all_personas).and_return([persona_class_double])
      allow(persona_class_double).to receive(:id).and_return(
        SiteSetting.inferred_concepts_generate_persona.to_i,
      )
      allow(persona_class_double).to receive(:new).and_return(persona_instance_double)
      allow(persona_instance_double).to receive(:class).and_return(persona_class_double)
      allow(persona_class_double).to receive(:default_llm_id).and_return(llm_model.id)
      allow(LlmModel).to receive(:find).with(llm_model.id).and_return(llm_model)
      allow(DiscourseAi::Personas::Bot).to receive(:as).and_return(bot_double)
      allow(bot_double).to receive(:reply).and_yield(nil, nil, :text)

      result = finder.identify_concepts(content)
      expect(result).to eq([])
    end
  end

  describe "#create_or_find_concepts" do
    it "returns empty array for blank concept names" do
      expect(finder.create_or_find_concepts([])).to eq([])
      expect(finder.create_or_find_concepts(nil)).to eq([])
    end

    it "creates new concepts for new names" do
      concept_names = %w[new_concept1 new_concept2]
      result = finder.create_or_find_concepts(concept_names)

      expect(result.length).to eq(2)
      expect(result.map(&:name)).to match_array(concept_names)
      expect(InferredConcept.where(name: concept_names).count).to eq(2)
    end

    it "finds existing concepts" do
      concept_names = %w[programming testing]
      result = finder.create_or_find_concepts(concept_names)

      expect(result.length).to eq(2)
      expect(result).to include(concept1, concept2)
    end

    it "handles mix of new and existing concepts" do
      concept_names = %w[programming new_concept]
      result = finder.create_or_find_concepts(concept_names)

      expect(result.length).to eq(2)
      expect(result.map(&:name)).to match_array(concept_names)
    end
  end

  describe "#find_candidate_topics" do
    let!(:good_topic) { Fabricate(:topic, posts_count: 6, views: 150, like_count: 12) }
    let!(:bad_topic) { Fabricate(:topic, posts_count: 2, views: 50, like_count: 2) }
    let!(:topic_with_concepts) do
      t = Fabricate(:topic, posts_count: 8, views: 200, like_count: 20)
      t.inferred_concepts << concept1
      t
    end

    it "finds topics meeting minimum criteria" do
      candidates = finder.find_candidate_topics(min_posts: 5, min_views: 100, min_likes: 10)

      expect(candidates).to include(good_topic)
      expect(candidates).not_to include(bad_topic)
      expect(candidates).not_to include(topic_with_concepts) # already has concepts
    end

    it "respects limit parameter" do
      candidates = finder.find_candidate_topics(limit: 1)
      expect(candidates.length).to be <= 1
    end

    it "excludes specified topic IDs" do
      candidates = finder.find_candidate_topics(exclude_topic_ids: [good_topic.id])
      expect(candidates).not_to include(good_topic)
    end

    it "filters by category IDs when provided" do
      category = Fabricate(:category)
      topic_in_category =
        Fabricate(:topic, category: category, posts_count: 6, views: 150, like_count: 12)

      candidates = finder.find_candidate_topics(category_ids: [category.id])

      expect(candidates).to include(topic_in_category)
      expect(candidates).not_to include(good_topic)
    end

    it "filters by creation date" do
      old_topic =
        Fabricate(:topic, posts_count: 6, views: 150, like_count: 12, created_at: 45.days.ago)

      candidates = finder.find_candidate_topics(created_after: 30.days.ago)

      expect(candidates).to include(good_topic)
      expect(candidates).not_to include(old_topic)
    end
  end

  describe "#find_candidate_posts" do
    let!(:good_post) { Fabricate(:post, like_count: 8, post_number: 2) }
    let!(:bad_post) { Fabricate(:post, like_count: 2, post_number: 2) }
    let!(:first_post) { Fabricate(:post, like_count: 10, post_number: 1) }
    let!(:post_with_concepts) do
      p = Fabricate(:post, like_count: 15, post_number: 3)
      p.inferred_concepts << concept1
      p
    end

    it "finds posts meeting minimum criteria" do
      candidates = finder.find_candidate_posts(min_likes: 5)

      expect(candidates).to include(good_post)
      expect(candidates).not_to include(bad_post)
      expect(candidates).not_to include(post_with_concepts) # already has concepts
    end

    it "excludes first posts by default" do
      candidates = finder.find_candidate_posts(min_likes: 5)

      expect(candidates).not_to include(first_post)
    end

    it "can include first posts when specified" do
      candidates = finder.find_candidate_posts(min_likes: 5, exclude_first_posts: false)

      expect(candidates).to include(first_post)
    end

    it "respects limit parameter" do
      candidates = finder.find_candidate_posts(limit: 1)
      expect(candidates.length).to be <= 1
    end

    it "excludes specified post IDs" do
      candidates = finder.find_candidate_posts(exclude_post_ids: [good_post.id])
      expect(candidates).not_to include(good_post)
    end

    it "filters by category IDs when provided" do
      category = Fabricate(:category)
      topic_in_category = Fabricate(:topic, category: category)
      post_in_category = Fabricate(:post, topic: topic_in_category, like_count: 8, post_number: 2)

      candidates = finder.find_candidate_posts(category_ids: [category.id])

      expect(candidates).to include(post_in_category)
      expect(candidates).not_to include(good_post)
    end

    it "filters by creation date" do
      old_post = Fabricate(:post, like_count: 8, post_number: 2, created_at: 45.days.ago)

      candidates = finder.find_candidate_posts(created_after: 30.days.ago)

      expect(candidates).to include(good_post)
      expect(candidates).not_to include(old_post)
    end
  end

  describe "#deduplicate_concepts" do
    it "returns empty result for blank concept names" do
      result = finder.deduplicate_concepts([])
      expect(result).to eq({ deduplicated_concepts: [], mapping: {} })

      result = finder.deduplicate_concepts(nil)
      expect(result).to eq({ deduplicated_concepts: [], mapping: {} })
    end

    it "uses ConceptDeduplicator persona to deduplicate concepts" do
      concept_names = ["ruby", "Ruby programming", "testing", "unit testing"]
      structured_output_double = instance_double("DiscourseAi::Completions::StructuredOutput")

      persona_class_double = double("PersonaClass") # rubocop:disable RSpec/VerifiedDoubles
      persona_instance_double = double("PersonaInstance") # rubocop:disable RSpec/VerifiedDoubles
      bot_double = instance_double("DiscourseAi::Personas::Bot")

      allow(AiPersona).to receive(:all_personas).and_return([persona_class_double])
      allow(persona_class_double).to receive(:id).and_return(
        SiteSetting.inferred_concepts_deduplicate_persona.to_i,
      )
      allow(persona_class_double).to receive(:new).and_return(persona_instance_double)
      allow(persona_instance_double).to receive(:class).and_return(persona_class_double)
      allow(persona_class_double).to receive(:default_llm_id).and_return(llm_model.id)
      allow(LlmModel).to receive(:find).with(llm_model.id).and_return(llm_model)
      allow(DiscourseAi::Personas::Bot).to receive(:as).and_return(bot_double)
      allow(bot_double).to receive(:reply).and_yield(
        structured_output_double,
        nil,
        :structured_output,
      )
      allow(structured_output_double).to receive(:read_buffered_property).with(
        :streamlined_tags,
      ).and_return(%w[ruby testing])

      result = finder.deduplicate_concepts(concept_names)
      expect(result).to eq(%w[ruby testing])
    end

    it "handles no structured output gracefully" do
      concept_names = %w[concept1 concept2]

      persona_class_double = double("PersonaClass") # rubocop:disable RSpec/VerifiedDoubles
      persona_instance_double = double("PersonaInstance") # rubocop:disable RSpec/VerifiedDoubles
      bot_double = instance_double("DiscourseAi::Personas::Bot")

      allow(AiPersona).to receive(:all_personas).and_return([persona_class_double])
      allow(persona_class_double).to receive(:id).and_return(
        SiteSetting.inferred_concepts_deduplicate_persona.to_i,
      )
      allow(persona_class_double).to receive(:new).and_return(persona_instance_double)
      allow(persona_instance_double).to receive(:class).and_return(persona_class_double)
      allow(persona_class_double).to receive(:default_llm_id).and_return(llm_model.id)
      allow(LlmModel).to receive(:find).with(llm_model.id).and_return(llm_model)
      allow(DiscourseAi::Personas::Bot).to receive(:as).and_return(bot_double)
      allow(bot_double).to receive(:reply).and_yield(nil, nil, :text)

      result = finder.deduplicate_concepts(concept_names)
      expect(result).to eq([])
    end
  end
end
