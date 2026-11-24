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

    it "validates description length" do
      concept = Fabricate.build(:inferred_concept, description: "a" * 1001)
      expect(concept).not_to be_valid
      expect(concept.errors[:description]).to be_present
    end

    it "validates case-insensitive slug uniqueness when explicitly provided" do
      Fabricate(:inferred_concept, name: "Ruby", slug: "ruby-lang")
      duplicate = Fabricate.build(:inferred_concept, name: "Ruby 2", slug: "RUBY-LANG")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:slug]).to include("has already been taken")
    end

    it "rejects setting a concept as its own parent" do
      concept = Fabricate(:inferred_concept, name: "ruby")
      concept.parent = concept

      expect(concept).not_to be_valid
      expect(concept.errors[:parent_id]).to be_present
    end

    it "validates relevance bounds on topic and post associations" do
      topic = Fabricate(:topic)
      post = Fabricate(:post)
      concept = Fabricate(:inferred_concept, name: "ruby")

      expect(
        InferredConceptTopic.new(inferred_concept: concept, topic: topic, relevance: -0.1),
      ).not_to be_valid
      expect(
        InferredConceptTopic.new(inferred_concept: concept, topic: topic, relevance: 1.1),
      ).not_to be_valid
      expect(
        InferredConceptPost.new(inferred_concept: concept, post: post, relevance: 1.5),
      ).not_to be_valid
      expect(
        InferredConceptTopic.new(inferred_concept: concept, topic: topic, relevance: 0.85),
      ).to be_valid
    end
  end

  describe "status" do
    it "defaults to active and supports candidate and retired transitions" do
      concept = Fabricate(:inferred_concept, name: "ruby")
      expect(concept).to be_active

      concept.candidate!
      expect(concept).to be_candidate
      expect(InferredConcept.candidate).to include(concept)

      concept.retired!
      expect(concept).to be_retired
      expect(InferredConcept.retired).to include(concept)
    end
  end

  describe "slug generation" do
    it "auto-generates and updates slug from name unless explicitly overridden" do
      concept = Fabricate(:inferred_concept, name: "Ruby Programming")
      expect(concept.slug).to eq("ruby-programming")

      concept.update!(name: "Python Programming")
      expect(concept.slug).to eq("python-programming")

      concept.update!(name: "Elixir Programming", slug: "elixir-custom")
      expect(concept.slug).to eq("elixir-custom")
    end

    it "falls back to an empty slug when auto-generated slug collides" do
      Fabricate(:inferred_concept, name: "API")
      second = Fabricate(:inferred_concept, name: "api")

      expect(second).to be_valid
      expect(second.slug).to eq("")
    end
  end

  describe "aliases and lookup" do
    it "normalizes aliases and excludes the concept's own name" do
      concept =
        Fabricate(
          :inferred_concept,
          name: "Kubernetes",
          aliases: ["  k8s ", "K8S", "kubernetes", "", "container orchestration"],
        )

      expect(concept.aliases).to eq(["k8s", "container orchestration"])
    end

    it "matches concepts by name or alias case-insensitively" do
      k8s = Fabricate(:inferred_concept, name: "Kubernetes", aliases: ["k8s"])
      other = Fabricate(:inferred_concept, name: "Docker")

      expect(InferredConcept.by_name_or_alias("K8S")).to contain_exactly(k8s)
      expect(InferredConcept.by_name_or_alias("kubernetes")).to contain_exactly(k8s)
      expect(InferredConcept.by_name_or_alias("podman")).to be_empty
      expect(InferredConcept.by_name_or_alias("docker")).to contain_exactly(other)
    end

    it "prioritizes active concepts over retired concepts with the same alias or name" do
      retired = Fabricate(:inferred_concept, name: "k8s", status: :retired)
      active = Fabricate(:inferred_concept, name: "Kubernetes", aliases: ["k8s"], status: :active)

      expect(InferredConcept.by_name_or_alias("k8s").first).to eq(active)
      expect(InferredConcept.by_name_or_alias("k8s")).to eq([active, retired])
    end
  end

  describe "hierarchy" do
    it "nullifies children's parent_id when the parent is destroyed" do
      parent = Fabricate(:inferred_concept, name: "Infrastructure")
      child = Fabricate(:inferred_concept, name: "Kubernetes", parent: parent)

      expect(parent.children).to contain_exactly(child)

      parent.destroy!

      expect(child.reload.parent_id).to be_nil
    end
  end

  describe "#text_for_embedding" do
    it "formats name, optional description, and optional aliases" do
      minimal = Fabricate.build(:inferred_concept, name: "Caching", description: "", aliases: [])
      expect(minimal.text_for_embedding).to eq("Caching")

      described =
        Fabricate.build(
          :inferred_concept,
          name: "Caching",
          description: "HTTP and Redis caching strategies",
          aliases: [],
        )
      expect(described.text_for_embedding).to eq("Caching\n\nHTTP and Redis caching strategies")

      full =
        Fabricate.build(
          :inferred_concept,
          name: "Caching",
          description: "HTTP and Redis caching strategies",
          aliases: %w[CDN memcached],
        )
      expect(full.text_for_embedding).to eq(
        "Caching\n\nHTTP and Redis caching strategies\n\nAlso known as: CDN, memcached",
      )
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

    it "deletes join rows and stored embeddings when destroyed" do
      vector_def = Fabricate(:cloudflare_embedding_def)
      schema = DiscourseAi::Embeddings::Schema.for(described_class, vector_def: vector_def)
      concept.topics << topic
      concept.posts << post
      schema.store(concept, [0.1] * vector_def.dimensions, "digest-1")

      concept.destroy!

      expect(InferredConceptTopic.where(inferred_concept_id: concept.id)).to be_empty
      expect(InferredConceptPost.where(inferred_concept_id: concept.id)).to be_empty
      expect(schema.find_by_target(concept)).to be_nil
    end
  end

  describe "database constraints" do
    it "has the expected schema" do
      concept = Fabricate(:inferred_concept)
      expect(concept).to respond_to(
        :name,
        :slug,
        :description,
        :status,
        :aliases,
        :parent_id,
        :created_at,
        :updated_at,
      )
    end
  end
end
