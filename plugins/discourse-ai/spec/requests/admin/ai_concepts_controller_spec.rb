# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiConceptsController do
  fab!(:admin)
  fab!(:user)
  fab!(:vector_def, :cloudflare_embedding_def)

  before do
    enable_current_plugin
    SiteSetting.ai_embeddings_selected_model = vector_def.id
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.inferred_concepts_enabled = true
    sign_in(admin)
  end

  describe "#index" do
    fab!(:active_concept) do
      Fabricate(
        :inferred_concept,
        name: "Kubernetes",
        description: "Container orchestration platform",
        aliases: %w[k8s kube],
        status: :active,
      )
    end
    fab!(:candidate_concept) do
      Fabricate(:inferred_concept, name: "Edge Caching", description: "CDN", status: :candidate)
    end
    fab!(:retired_concept) { Fabricate(:inferred_concept, name: "Legacy VM", status: :retired) }

    before do
      InferredConceptTopic.create!(inferred_concept: active_concept, topic: Fabricate(:topic))
      InferredConceptTopic.create!(inferred_concept: active_concept, topic: Fabricate(:topic))
      InferredConceptPost.create!(inferred_concept: candidate_concept, post: Fabricate(:post))
    end

    it "rejects non-admin users" do
      sign_in(user)
      get "/admin/plugins/discourse-ai/ai-concepts.json"
      expect(response.status).to eq(404)
    end

    it "lists concepts ordered by usage with counts and metadata" do
      get "/admin/plugins/discourse-ai/ai-concepts.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["ai_concepts"].map { |c| c["name"] }).to eq(
        ["Kubernetes", "Edge Caching", "Legacy VM"],
      )
      expect(json["ai_concepts"].first["topics_count"]).to eq(2)
      expect(json["ai_concepts"].second["posts_count"]).to eq(1)
      expect(json["meta"]["counts"]).to eq({ "active" => 1, "candidate" => 1, "retired" => 1 })
      expect(json["meta"]["enabled"]).to eq(true)
      expect(json["meta"]["embeddings_enabled"]).to eq(true)
    end

    it "filters by status, search query across aliases, and orders by name" do
      get "/admin/plugins/discourse-ai/ai-concepts.json",
          params: {
            status: "active",
            filter: "k8s",
          }
      expect(response.status).to eq(200)
      expect(response.parsed_body["ai_concepts"].map { |c| c["id"] }).to eq([active_concept.id])

      get "/admin/plugins/discourse-ai/ai-concepts.json",
          params: {
            status: "non_retired",
            order: "name",
          }
      expect(response.parsed_body["ai_concepts"].map { |c| c["name"] }).to eq(
        ["Edge Caching", "Kubernetes"],
      )
    end

    it "paginates results" do
      get "/admin/plugins/discourse-ai/ai-concepts.json", params: { per_page: 2, page: 1 }
      expect(response.parsed_body["ai_concepts"].size).to eq(2)
      expect(response.parsed_body["meta"]["has_more"]).to eq(true)

      get "/admin/plugins/discourse-ai/ai-concepts.json", params: { per_page: 2, page: 2 }
      expect(response.parsed_body["ai_concepts"].size).to eq(1)
      expect(response.parsed_body["meta"]["has_more"]).to eq(false)
    end
  end

  describe "#show" do
    it "returns concept details, child concepts, and visible public tagged topics ordered by relevance" do
      parent = Fabricate(:inferred_concept, name: "Infrastructure", status: :active)
      concept = Fabricate(:inferred_concept, name: "Kubernetes", parent: parent, status: :active)
      child = Fabricate(:inferred_concept, name: "Helm", parent: concept, status: :candidate)

      public_topic = Fabricate(:topic, title: "Public Kubernetes Deployment Guide")
      deleted_topic =
        Fabricate(:topic, title: "Deleted Kubernetes Guide", deleted_at: Time.zone.now)
      pm_topic = Fabricate(:private_message_topic, title: "Private Message Kubernetes Note")

      InferredConceptTopic.create!(
        inferred_concept: concept,
        topic: public_topic,
        relevance: 0.92,
        primary: true,
      )
      InferredConceptTopic.create!(inferred_concept: concept, topic: deleted_topic, relevance: 0.9)
      InferredConceptTopic.create!(inferred_concept: concept, topic: pm_topic, relevance: 0.99)

      get "/admin/plugins/discourse-ai/ai-concepts/#{concept.id}.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["ai_concept"]["parent_name"]).to eq("Infrastructure")
      expect(json["ai_concept"]["children_count"]).to eq(1)
      expect(json["children"].map { |c| c["id"] }).to eq([child.id])
      expect(json["topics"].map { |t| t["id"] }).to eq([public_topic.id])
      expect(json["topics"].first["primary"]).to eq(true)
    end
  end

  describe "#create" do
    it "creates a concept and enqueues embedding generation" do
      expect do
        post "/admin/plugins/discourse-ai/ai-concepts.json",
             params: {
               ai_concept: {
                 name: "Observability",
                 description: "Metrics, traces, and logs",
                 aliases: %w[o11y telemetry],
                 status: "active",
               },
             }
      end.to change { Jobs::GenerateEmbeddings.jobs.size }.by(1)

      expect(response.status).to eq(201)
      created = InferredConcept.find_by!(name: "Observability")
      expect(created.aliases).to eq(%w[o11y telemetry])
    end

    it "rejects retired parents and blank names" do
      retired = Fabricate(:inferred_concept, name: "Deprecated", status: :retired)

      post "/admin/plugins/discourse-ai/ai-concepts.json",
           params: {
             ai_concept: {
               name: "Child",
               parent_id: retired.id,
             },
           }
      expect(response.status).to eq(422)

      post "/admin/plugins/discourse-ai/ai-concepts.json", params: { ai_concept: { name: "" } }
      expect(response.status).to eq(422)
    end
  end

  describe "#update" do
    it "updates concept attributes, rejects cycles, and deletes embeddings on retire" do
      parent = Fabricate(:inferred_concept, name: "Infrastructure", status: :active)
      child = Fabricate(:inferred_concept, name: "Kubernetes", parent: parent, status: :active)
      DiscourseAi::Embeddings::Schema.for(InferredConcept).store(
        child,
        [0.1] * vector_def.dimensions,
        "child-vec",
      )

      put "/admin/plugins/discourse-ai/ai-concepts/#{parent.id}.json",
          params: {
            ai_concept: {
              parent_id: child.id,
            },
          }
      expect(response.status).to eq(422)

      put "/admin/plugins/discourse-ai/ai-concepts/#{child.id}.json",
          params: {
            ai_concept: {
              status: "retired",
            },
          }
      expect(response.status).to eq(200)
      expect(child.reload).to be_retired
      expect(DiscourseAi::Embeddings::Schema.for(InferredConcept).find_by_target(child)).to be_nil
    end
  end

  describe "#destroy" do
    it "destroys a concept and returns 204" do
      concept = Fabricate(:inferred_concept, name: "Temporary")

      delete "/admin/plugins/discourse-ai/ai-concepts/#{concept.id}.json"

      expect(response.status).to eq(204)
      expect(InferredConcept.find_by(id: concept.id)).to be_nil
    end
  end

  describe "#merge" do
    it "losslessly merges source into target canonical concept" do
      source = Fabricate(:inferred_concept, name: "k8s", status: :candidate)
      target = Fabricate(:inferred_concept, name: "Kubernetes", status: :active)
      topic = Fabricate(:topic)
      InferredConceptTopic.create!(inferred_concept: source, topic: topic, relevance: 0.9)

      post "/admin/plugins/discourse-ai/ai-concepts/#{source.id}/merge.json",
           params: {
             target_concept_id: target.id,
           }

      expect(response.status).to eq(200)
      expect(source.reload).to be_retired
      expect(target.reload.topics).to contain_exactly(topic)
      expect(response.parsed_body["ai_concept"]["id"]).to eq(target.id)
    end

    it "rejects merging into self or retired targets" do
      concept = Fabricate(:inferred_concept, name: "Kubernetes", status: :active)
      retired = Fabricate(:inferred_concept, name: "Old", status: :retired)

      post "/admin/plugins/discourse-ai/ai-concepts/#{concept.id}/merge.json",
           params: {
             target_concept_id: concept.id,
           }
      expect(response.status).to eq(422)

      post "/admin/plugins/discourse-ai/ai-concepts/#{concept.id}/merge.json",
           params: {
             target_concept_id: retired.id,
           }
      expect(response.status).to eq(422)
    end
  end

  describe "#curate" do
    it "enqueues the curation job when enabled and returns 422 when disabled" do
      expect do post "/admin/plugins/discourse-ai/ai-concepts/curate.json" end.to change {
        Jobs::CurateInferredConcepts.jobs.size
      }.by(1)
      expect(response.status).to eq(204)

      SiteSetting.inferred_concepts_enabled = false
      post "/admin/plugins/discourse-ai/ai-concepts/curate.json"
      expect(response.status).to eq(422)
    end
  end

  describe "client translations" do
    it "keeps secrets.modal and concepts keys under their expected scopes" do
      expect(I18n.t("js.discourse_ai.secrets.modal.title")).to eq("Create new credential")
      expect(I18n.t("js.discourse_ai.concepts.short_title")).to eq("Concepts")
    end
  end
end
