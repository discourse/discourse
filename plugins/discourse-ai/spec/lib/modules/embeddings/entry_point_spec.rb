# frozen_string_literal: true

describe DiscourseAi::Embeddings::EntryPoint do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  fab!(:embedding_definition)

  before do
    enable_current_plugin
    SiteSetting.ai_embeddings_selected_model = embedding_definition.id
  end

  describe "registering event callbacks" do
    context "when creating a topic" do
      let(:creator) do
        PostCreator.new(
          user,
          raw: "this is the new content for my topic",
          title: "this is my new topic title",
        )
      end

      it "queues a job on create if embeddings is enabled" do
        SiteSetting.ai_embeddings_enabled = true

        expect { creator.create }.to change(Jobs::GenerateEmbeddings.jobs, :size).by(1) # topic_created
      end

      it "queues two jobs on create if embeddings is enabled" do
        SiteSetting.ai_embeddings_enabled = true

        expect { creator.create }.to change(Jobs::GenerateEmbeddings.jobs, :size).by(1) # topic_created AND post_created
      end

      it "does nothing if embeddings analysis is disabled" do
        SiteSetting.ai_embeddings_enabled = false

        expect { creator.create }.not_to change(Jobs::GenerateEmbeddings.jobs, :size)
      end
    end
  end

  describe "similar_topic_candidate_ids modifier" do
    # The Distance gap to target increases for each element of topics.
    def seed_embeddings(topics)
      schema = DiscourseAi::Embeddings::Schema.for(Topic)
      base_value = 1

      topics.each_with_index do |t, idx|
        base_value -= 0.01
        schema.store(t, [base_value] * embedding_definition.dimensions, "digest")
      end
    end

    def stub_query_embedding(query)
      embedding = [1] * embedding_definition.dimensions

      EmbeddingsGenerationStubs.hugging_face_service(query, embedding)
    end

    fab!(:category)
    fab!(:normal_topic_1) { Fabricate(:topic, category: category) }
    fab!(:normal_topic_2) { Fabricate(:topic, category: category) }
    fab!(:private_topic) { Fabricate(:private_message_topic) }

    let(:query) { "title\n\nraw" }

    fab!(:embedding_definition)

    before do
      [normal_topic_1, normal_topic_2, private_topic].each_with_index do |t, idx|
        Fabricate(
          :post,
          topic: t,
          user: t.user,
          post_number: 1,
          raw: "This is a post with raw ##{idx + 1}",
        )
      end

      seed_embeddings([normal_topic_1, private_topic])
      stub_query_embedding(query)
      SiteSetting.ai_embeddings_enabled = true
      SiteSetting.ai_embeddings_selected_model = embedding_definition.id
    end

    it "appends topic IDs" do
      similar_topics = Topic.similar_to("title", "raw")

      expect(similar_topics.map(&:id)).to contain_exactly(normal_topic_1.id)
    end

    it "does nothing if embeddings is not enabled" do
      SiteSetting.ai_embeddings_enabled = false

      similar_topics = Topic.similar_to("title", "raw")

      expect(similar_topics.map(&:id)).to be_empty
    end
  end
end
