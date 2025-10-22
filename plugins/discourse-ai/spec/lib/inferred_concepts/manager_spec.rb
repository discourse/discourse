# frozen_string_literal: true

RSpec.describe DiscourseAi::InferredConcepts::Manager do
  subject(:manager) { described_class.new }

  fab!(:topic)
  fab!(:post)
  fab!(:concept1) { Fabricate(:inferred_concept, name: "programming") }
  fab!(:concept2) { Fabricate(:inferred_concept, name: "testing") }

  before { enable_current_plugin }

  describe "#list_concepts" do
    it "returns all concepts sorted by name" do
      concepts = manager.list_concepts
      expect(concepts).to include("programming", "testing")
      expect(concepts).to eq(concepts.sort)
    end

    it "respects limit parameter" do
      concepts = manager.list_concepts(limit: 1)
      expect(concepts.length).to eq(1)
    end

    it "returns empty array when no concepts exist" do
      InferredConcept.destroy_all
      concepts = manager.list_concepts
      expect(concepts).to eq([])
    end
  end

  describe "#generate_concepts_from_content" do
    before do
      SiteSetting.inferred_concepts_generate_persona = -1
      SiteSetting.inferred_concepts_enabled = true
    end

    it "returns empty array for blank content" do
      expect(manager.generate_concepts_from_content("")).to eq([])
      expect(manager.generate_concepts_from_content(nil)).to eq([])
    end

    it "delegates to Finder#identify_concepts" do
      content = "This is about Ruby programming"
      finder = instance_double(DiscourseAi::InferredConcepts::Finder)
      allow(DiscourseAi::InferredConcepts::Finder).to receive(:new).and_return(finder)

      allow(finder).to receive(:identify_concepts).with(content).and_return(%w[ruby programming])

      allow(finder).to receive(:create_or_find_concepts).with(%w[ruby programming]).and_return(
        [concept1],
      )

      result = manager.generate_concepts_from_content(content)
      expect(result).to eq([concept1])
    end
  end

  describe "#generate_concepts_from_topic" do
    it "returns empty array for blank topic" do
      expect(manager.generate_concepts_from_topic(nil)).to eq([])
    end

    it "extracts content and generates concepts" do
      applier = instance_double(DiscourseAi::InferredConcepts::Applier)
      allow(DiscourseAi::InferredConcepts::Applier).to receive(:new).and_return(applier)
      allow(applier).to receive(:topic_content_for_analysis).with(topic).and_return("topic content")

      # Mock the finder instead of stubbing subject
      finder = instance_double(DiscourseAi::InferredConcepts::Finder)
      allow(DiscourseAi::InferredConcepts::Finder).to receive(:new).and_return(finder)
      allow(finder).to receive(:identify_concepts).with("topic content").and_return(%w[programming])
      allow(finder).to receive(:create_or_find_concepts).with(%w[programming]).and_return(
        [concept1],
      )

      result = manager.generate_concepts_from_topic(topic)
      expect(result).to eq([concept1])
    end
  end

  describe "#generate_concepts_from_post" do
    it "returns empty array for blank post" do
      expect(manager.generate_concepts_from_post(nil)).to eq([])
    end

    it "extracts content and generates concepts" do
      applier = instance_double(DiscourseAi::InferredConcepts::Applier)
      allow(DiscourseAi::InferredConcepts::Applier).to receive(:new).and_return(applier)
      allow(applier).to receive(:post_content_for_analysis).with(post).and_return("post content")

      # Mock the finder instead of stubbing subject
      finder = instance_double(DiscourseAi::InferredConcepts::Finder)
      allow(DiscourseAi::InferredConcepts::Finder).to receive(:new).and_return(finder)
      allow(finder).to receive(:identify_concepts).with("post content").and_return(%w[testing])
      allow(finder).to receive(:create_or_find_concepts).with(%w[testing]).and_return([concept1])

      result = manager.generate_concepts_from_post(post)
      expect(result).to eq([concept1])
    end
  end

  describe "#match_topic_to_concepts" do
    it "returns empty array for blank topic" do
      expect(manager.match_topic_to_concepts(nil)).to eq([])
    end

    it "delegates to Applier#match_existing_concepts" do
      applier = instance_double(DiscourseAi::InferredConcepts::Applier)
      allow(DiscourseAi::InferredConcepts::Applier).to receive(:new).and_return(applier)

      allow(applier).to receive(:match_existing_concepts).with(topic).and_return([concept1])

      result = manager.match_topic_to_concepts(topic)
      expect(result).to eq([concept1])
    end
  end

  describe "#match_post_to_concepts" do
    it "returns empty array for blank post" do
      expect(manager.match_post_to_concepts(nil)).to eq([])
    end

    it "delegates to Applier#match_existing_concepts_for_post" do
      applier = instance_double(DiscourseAi::InferredConcepts::Applier)
      allow(DiscourseAi::InferredConcepts::Applier).to receive(:new).and_return(applier)

      allow(applier).to receive(:match_existing_concepts_for_post).with(post).and_return([concept1])

      result = manager.match_post_to_concepts(post)
      expect(result).to eq([concept1])
    end
  end

  describe "#search_topics_by_concept" do
    it "returns empty array for non-existent concept" do
      result = manager.search_topics_by_concept("nonexistent")
      expect(result).to eq([])
    end

    it "returns topics associated with concept" do
      concept1.topics << topic
      result = manager.search_topics_by_concept("programming")
      expect(result).to include(topic)
    end
  end

  describe "#search_posts_by_concept" do
    it "returns empty array for non-existent concept" do
      result = manager.search_posts_by_concept("nonexistent")
      expect(result).to eq([])
    end

    it "returns posts associated with concept" do
      concept1.posts << post
      result = manager.search_posts_by_concept("programming")
      expect(result).to include(post)
    end
  end

  describe "#match_content_to_concepts" do
    it "returns empty array when no concepts exist" do
      InferredConcept.destroy_all
      result = manager.match_content_to_concepts("some content")
      expect(result).to eq([])
    end

    it "delegates to Applier#match_concepts_to_content" do
      content = "programming content"
      existing_concepts = %w[programming testing]
      applier = instance_double(DiscourseAi::InferredConcepts::Applier)

      all_double = instance_double(ActiveRecord::Relation)
      allow(InferredConcept).to receive(:all).and_return(all_double)
      allow(all_double).to receive(:pluck).with(:name).and_return(existing_concepts)

      allow(DiscourseAi::InferredConcepts::Applier).to receive(:new).and_return(applier)
      allow(applier).to receive(:match_concepts_to_content).with(
        content,
        existing_concepts,
      ).and_return(["programming"])

      result = manager.match_content_to_concepts(content)
      expect(result).to eq(["programming"])
    end
  end

  describe "#find_candidate_topics" do
    it "delegates to Finder#find_candidate_topics with options" do
      opts = { limit: 50, min_posts: 3 }
      finder = instance_double(DiscourseAi::InferredConcepts::Finder)
      allow(DiscourseAi::InferredConcepts::Finder).to receive(:new).and_return(finder)

      allow(finder).to receive(:find_candidate_topics).with(**opts).and_return([topic])

      result = manager.find_candidate_topics(opts)
      expect(result).to eq([topic])
    end
  end

  describe "#find_candidate_posts" do
    it "delegates to Finder#find_candidate_posts with options" do
      opts = { limit: 25, min_likes: 2 }
      finder = instance_double(DiscourseAi::InferredConcepts::Finder)
      allow(DiscourseAi::InferredConcepts::Finder).to receive(:new).and_return(finder)

      allow(finder).to receive(:find_candidate_posts).with(**opts).and_return([post])

      result = manager.find_candidate_posts(opts)
      expect(result).to eq([post])
    end
  end

  describe "#deduplicate_concepts_by_letter" do
    before do
      # Create test concepts
      %w[apple application banana berry cat car dog].each do |name|
        Fabricate(:inferred_concept, name: name)
      end
    end

    it "groups concepts by first letter and deduplicates" do
      finder = instance_double(DiscourseAi::InferredConcepts::Finder)
      allow(DiscourseAi::InferredConcepts::Finder).to receive(:new).and_return(finder)

      allow(finder).to receive(:deduplicate_concepts).at_least(:once).and_return(
        %w[apple banana cat dog],
      )

      allow(InferredConcept).to receive(:where).and_call_original
      allow(InferredConcept).to receive(:insert_all).and_call_original

      manager.deduplicate_concepts_by_letter
    end

    it "handles empty concept list" do
      InferredConcept.destroy_all
      expect { manager.deduplicate_concepts_by_letter }.not_to raise_error
    end
  end
end
