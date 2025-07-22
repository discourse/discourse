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
end
