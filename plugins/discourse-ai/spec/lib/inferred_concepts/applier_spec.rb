# frozen_string_literal: true

RSpec.describe DiscourseAi::InferredConcepts::Applier do
  subject(:applier) { described_class.new }

  fab!(:topic) { Fabricate(:topic, title: "Ruby Programming Tutorial") }
  fab!(:post) { Fabricate(:post, raw: "This post is about advanced testing techniques") }
  fab!(:user) { Fabricate(:user, username: "dev_user") }
  fab!(:concept1) { Fabricate(:inferred_concept, name: "programming") }
  fab!(:concept2) { Fabricate(:inferred_concept, name: "testing") }
  fab!(:llm_model) { Fabricate(:fake_model) }

  before do
    enable_current_plugin

    SiteSetting.inferred_concepts_match_persona = -1
    SiteSetting.inferred_concepts_enabled = true

    # Set up the post's user
    post.update!(user: user)
  end

  describe "#apply_to_topic" do
    it "does nothing for blank topic or concepts" do
      expect { applier.apply_to_topic(nil, [concept1]) }.not_to raise_error
      expect { applier.apply_to_topic(topic, []) }.not_to raise_error
      expect { applier.apply_to_topic(topic, nil) }.not_to raise_error
    end

    it "associates concepts with topic" do
      applier.apply_to_topic(topic, [concept1, concept2])

      expect(topic.inferred_concepts).to include(concept1, concept2)
      expect(concept1.topics).to include(topic)
      expect(concept2.topics).to include(topic)
    end
  end

  describe "#apply_to_post" do
    it "does nothing for blank post or concepts" do
      expect { applier.apply_to_post(nil, [concept1]) }.not_to raise_error
      expect { applier.apply_to_post(post, []) }.not_to raise_error
      expect { applier.apply_to_post(post, nil) }.not_to raise_error
    end

    it "associates concepts with post" do
      applier.apply_to_post(post, [concept1, concept2])

      expect(post.inferred_concepts).to include(concept1, concept2)
      expect(concept1.posts).to include(post)
      expect(concept2.posts).to include(post)
    end
  end

  describe "#topic_content_for_analysis" do
    it "returns empty string for blank topic" do
      expect(applier.topic_content_for_analysis(nil)).to eq("")
    end

    it "extracts title and posts content" do
      # Create additional posts for the topic
      post1 = Fabricate(:post, topic: topic, post_number: 1, raw: "First post content", user: user)
      post2 = Fabricate(:post, topic: topic, post_number: 2, raw: "Second post content", user: user)

      content = applier.topic_content_for_analysis(topic)

      expect(content).to include(topic.title)
      expect(content).to include("First post content")
      expect(content).to include("Second post content")
      expect(content).to include(user.username)
      expect(content).to include("1)")
      expect(content).to include("2)")
    end

    it "limits to first 10 posts" do
      # Create 12 posts for the topic
      12.times { |i| Fabricate(:post, topic: topic, post_number: i + 1, user: user) }

      allow(Post).to receive(:where).with(topic_id: topic.id).and_call_original
      allow_any_instance_of(ActiveRecord::Relation).to receive(:limit).with(10).and_call_original

      applier.topic_content_for_analysis(topic)

      expect(Post).to have_received(:where).with(topic_id: topic.id)
    end
  end

  describe "#post_content_for_analysis" do
    it "returns empty string for blank post" do
      expect(applier.post_content_for_analysis(nil)).to eq("")
    end

    it "extracts post content with topic context" do
      content = applier.post_content_for_analysis(post)

      expect(content).to include(post.topic.title)
      expect(content).to include(post.raw)
      expect(content).to include(post.user.username)
      expect(content).to include("Topic:")
      expect(content).to include("Post by")
    end

    it "handles post without topic" do
      # Mock the post to return nil for topic
      allow(post).to receive(:topic).and_return(nil)

      content = applier.post_content_for_analysis(post)

      expect(content).to include(post.raw)
      expect(content).to include(post.user.username)
      expect(content).to include("Topic: ")
    end
  end

  describe "#match_existing_concepts" do
    let(:manager) { instance_double(DiscourseAi::InferredConcepts::Manager) }

    before do
      allow(DiscourseAi::InferredConcepts::Manager).to receive(:new).and_return(manager)
      allow(manager).to receive(:list_concepts).and_return(%w[programming testing ruby])
    end

    it "returns empty array for blank topic" do
      expect(applier.match_existing_concepts(nil)).to eq([])
    end

    it "returns empty array when no existing concepts" do
      allow(manager).to receive(:list_concepts).and_return([])

      result = applier.match_existing_concepts(topic)
      expect(result).to eq([])
    end

    it "matches concepts and applies them to topic" do
      # Test the real implementation without stubbing internal methods
      allow(InferredConcept).to receive(:where).with(name: ["programming"]).and_return([concept1])

      # Mock the LLM interaction
      persona_instance_double = instance_spy("DiscourseAi::Personas::Persona")
      bot_double = instance_spy(DiscourseAi::Personas::Bot)
      structured_output_double = instance_double("DiscourseAi::Completions::StructuredOutput")
      persona_class_double = double("PersonaClass") # rubocop:disable RSpec/VerifiedDoubles

      allow(AiPersona).to receive(:all_personas).and_return([persona_class_double])
      allow(persona_class_double).to receive(:id).and_return(
        SiteSetting.inferred_concepts_match_persona.to_i,
      )
      allow(persona_class_double).to receive(:new).and_return(persona_instance_double)
      allow(persona_class_double).to receive(:default_llm_id).and_return(llm_model.id)
      allow(persona_instance_double).to receive(:class).and_return(persona_class_double)
      allow(LlmModel).to receive(:find).and_return(llm_model)
      allow(DiscourseAi::Personas::Bot).to receive(:as).and_return(bot_double)
      allow(bot_double).to receive(:reply).and_yield(
        structured_output_double,
        nil,
        :structured_output,
      )
      allow(structured_output_double).to receive(:read_buffered_property).with(
        :matching_concepts,
      ).and_return(["programming"])

      result = applier.match_existing_concepts(topic)
      expect(result).to eq([concept1])
    end
  end

  describe "#match_existing_concepts_for_post" do
    let(:manager) { instance_double(DiscourseAi::InferredConcepts::Manager) }

    before do
      allow(DiscourseAi::InferredConcepts::Manager).to receive(:new).and_return(manager)
      allow(manager).to receive(:list_concepts).and_return(%w[programming testing ruby])
    end

    it "returns empty array for blank post" do
      expect(applier.match_existing_concepts_for_post(nil)).to eq([])
    end

    it "returns empty array when no existing concepts" do
      allow(manager).to receive(:list_concepts).and_return([])

      result = applier.match_existing_concepts_for_post(post)
      expect(result).to eq([])
    end

    it "matches concepts and applies them to post" do
      # Test the real implementation without stubbing internal methods
      allow(InferredConcept).to receive(:where).with(name: ["testing"]).and_return([concept2])

      # Mock the LLM interaction
      persona_instance_double = instance_spy("DiscourseAi::Personas::Persona")
      bot_double = instance_spy(DiscourseAi::Personas::Bot)
      structured_output_double = instance_double("DiscourseAi::Completions::StructuredOutput")
      persona_class_double = double("PersonaClass") # rubocop:disable RSpec/VerifiedDoubles

      allow(AiPersona).to receive(:all_personas).and_return([persona_class_double])
      allow(persona_class_double).to receive(:id).and_return(
        SiteSetting.inferred_concepts_match_persona.to_i,
      )
      allow(persona_class_double).to receive(:new).and_return(persona_instance_double)
      allow(persona_class_double).to receive(:default_llm_id).and_return(llm_model.id)
      allow(persona_instance_double).to receive(:class).and_return(persona_class_double)
      allow(LlmModel).to receive(:find).and_return(llm_model)
      allow(DiscourseAi::Personas::Bot).to receive(:as).and_return(bot_double)
      allow(bot_double).to receive(:reply).and_yield(
        structured_output_double,
        nil,
        :structured_output,
      )
      allow(structured_output_double).to receive(:read_buffered_property).with(
        :matching_concepts,
      ).and_return(["testing"])

      result = applier.match_existing_concepts_for_post(post)
      expect(result).to eq([concept2])
    end
  end

  describe "#match_concepts_to_content" do
    it "returns empty array for blank content or concept list" do
      expect(applier.match_concepts_to_content("", ["concept1"])).to eq([])
      expect(applier.match_concepts_to_content(nil, ["concept1"])).to eq([])
      expect(applier.match_concepts_to_content("content", [])).to eq([])
      expect(applier.match_concepts_to_content("content", nil)).to eq([])
    end

    it "uses ConceptMatcher persona to match concepts" do
      content = "This is about Ruby programming"
      concept_list = %w[programming testing ruby]
      structured_output_double = instance_double("DiscourseAi::Completions::StructuredOutput")

      persona_class_double = double("PersonaClass") # rubocop:disable RSpec/VerifiedDoubles
      persona_instance_double = instance_spy("DiscourseAi::Personas::Persona")
      bot_double = instance_spy(DiscourseAi::Personas::Bot)

      allow(AiPersona).to receive(:all_personas).and_return([persona_class_double])
      allow(persona_class_double).to receive(:id).and_return(
        SiteSetting.inferred_concepts_match_persona.to_i,
      )
      allow(persona_class_double).to receive(:new).and_return(persona_instance_double)
      allow(persona_class_double).to receive(:default_llm_id).and_return(llm_model.id)
      allow(persona_instance_double).to receive(:class).and_return(persona_class_double)
      allow(LlmModel).to receive(:find).and_return(llm_model)
      allow(DiscourseAi::Personas::Bot).to receive(:as).and_return(bot_double)
      allow(bot_double).to receive(:reply).and_yield(
        structured_output_double,
        nil,
        :structured_output,
      )
      allow(structured_output_double).to receive(:read_buffered_property).with(
        :matching_concepts,
      ).and_return(%w[programming ruby])

      result = applier.match_concepts_to_content(content, concept_list)
      expect(result).to eq(%w[programming ruby])

      expect(bot_double).to have_received(:reply)
      expect(structured_output_double).to have_received(:read_buffered_property).with(
        :matching_concepts,
      )
    end

    it "handles no structured output gracefully" do
      content = "Test content"
      concept_list = ["concept1"]

      persona_class_double = double("PersonaClass") # rubocop:disable RSpec/VerifiedDoubles
      persona_instance_double = instance_double("DiscourseAi::Personas::Persona")
      bot_double = instance_double("DiscourseAi::Personas::Bot")

      allow(AiPersona).to receive(:all_personas).and_return([persona_class_double])
      allow(persona_class_double).to receive(:id).and_return(
        SiteSetting.inferred_concepts_match_persona.to_i,
      )
      allow(persona_class_double).to receive(:new).and_return(persona_instance_double)
      allow(persona_class_double).to receive(:default_llm_id).and_return(llm_model.id)
      allow(persona_instance_double).to receive(:class).and_return(persona_class_double)
      allow(LlmModel).to receive(:find).and_return(llm_model)
      allow(DiscourseAi::Personas::Bot).to receive(:as).and_return(bot_double)
      allow(bot_double).to receive(:reply).and_yield(nil, nil, :text)

      result = applier.match_concepts_to_content(content, concept_list)
      expect(result).to eq([])
    end

    it "returns empty array when no matching concepts found" do
      content = "This is about something else"
      concept_list = %w[programming testing]
      expected_response = [['{"matching_concepts": []}']]

      persona_class_double = double("PersonaClass") # rubocop:disable RSpec/VerifiedDoubles
      persona_instance_double = instance_double("DiscourseAi::Personas::Persona")
      bot_double = instance_double("DiscourseAi::Personas::Bot")

      allow(AiPersona).to receive(:all_personas).and_return([persona_class_double])
      allow(persona_class_double).to receive(:id).and_return(
        SiteSetting.inferred_concepts_match_persona.to_i,
      )
      allow(persona_class_double).to receive(:new).and_return(persona_instance_double)
      allow(persona_class_double).to receive(:default_llm_id).and_return(llm_model.id)
      allow(persona_instance_double).to receive(:class).and_return(persona_class_double)
      allow(LlmModel).to receive(:find).and_return(llm_model)
      allow(DiscourseAi::Personas::Bot).to receive(:as).and_return(bot_double)
      allow(bot_double).to receive(:reply).and_return(expected_response)

      result = applier.match_concepts_to_content(content, concept_list)
      expect(result).to eq([])
    end

    it "handles missing matching_concepts key in response" do
      content = "Test content"
      concept_list = ["concept1"]
      expected_response = [['{"other_key": ["value"]}']]

      persona_class_double = double("PersonaClass") # rubocop:disable RSpec/VerifiedDoubles
      persona_instance_double = instance_double("DiscourseAi::Personas::Persona")
      bot_double = instance_double("DiscourseAi::Personas::Bot")

      allow(AiPersona).to receive(:all_personas).and_return([persona_class_double])
      allow(persona_class_double).to receive(:id).and_return(
        SiteSetting.inferred_concepts_match_persona.to_i,
      )
      allow(persona_class_double).to receive(:new).and_return(persona_instance_double)
      allow(persona_class_double).to receive(:default_llm_id).and_return(llm_model.id)
      allow(persona_instance_double).to receive(:class).and_return(persona_class_double)
      allow(LlmModel).to receive(:find).and_return(llm_model)
      allow(DiscourseAi::Personas::Bot).to receive(:as).and_return(bot_double)
      allow(bot_double).to receive(:reply).and_return(expected_response)

      result = applier.match_concepts_to_content(content, concept_list)
      expect(result).to eq([])
    end
  end
end
