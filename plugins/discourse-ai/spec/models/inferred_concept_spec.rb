# frozen_string_literal: true

RSpec.describe InferredConcept do
  before { enable_current_plugin }

  describe "validations" do
    it "requires a name" do
      concept = InferredConcept.new
      expect(concept).not_to be_valid
      expect(concept.errors[:name]).to include("can't be blank")
    end

    it "requires unique names" do
      Fabricate(:inferred_concept, name: "ruby")
      concept = InferredConcept.new(name: "ruby")
      expect(concept).not_to be_valid
      expect(concept.errors[:name]).to include("has already been taken")
    end

    it "is valid with a unique name" do
      concept = Fabricate(:inferred_concept, name: "programming")
      expect(concept).to be_valid
    end
  end

  describe "associations" do
    fab!(:topic)
    fab!(:post)
    fab!(:concept) { Fabricate(:inferred_concept, name: "programming") }

    it "can be associated with topics" do
      concept.topics << topic
      expect(concept.topics).to include(topic)
      expect(topic.inferred_concepts).to include(concept)
    end

    it "can be associated with posts" do
      concept.posts << post
      expect(concept.posts).to include(post)
      expect(post.inferred_concepts).to include(concept)
    end

    it "can have multiple topics and posts" do
      topic2 = Fabricate(:topic)
      post2 = Fabricate(:post)

      concept.topics << [topic, topic2]
      concept.posts << [post, post2]

      expect(concept.topics.count).to eq(2)
      expect(concept.posts.count).to eq(2)
    end
  end

  describe "database constraints" do
    it "has the expected schema" do
      concept = Fabricate(:inferred_concept)
      expect(concept).to respond_to(:name)
      expect(concept).to respond_to(:created_at)
      expect(concept).to respond_to(:updated_at)
    end
  end
end
