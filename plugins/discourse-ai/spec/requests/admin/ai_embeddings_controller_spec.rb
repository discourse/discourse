# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiEmbeddingsController do
  fab!(:admin)

  let(:valid_attrs) do
    {
      display_name: "Embedding config test",
      dimensions: 1001,
      max_sequence_length: 234,
      pg_function: "<#>",
      provider: "hugging_face",
      url: "https://test.com/api/v1/embeddings",
      api_key: "test",
      tokenizer_class: "DiscourseAi::Tokenizer::BgeM3Tokenizer",
      embed_prompt: "I come first:",
      search_prompt: "prefix for search",
      matryoshka_dimensions: true,
    }
  end

  before do
    enable_current_plugin
    sign_in(admin)
  end

  describe "POST #create" do
    context "with valid attrs" do
      it "creates a new embedding definition" do
        post "/admin/plugins/discourse-ai/ai-embeddings.json", params: { ai_embedding: valid_attrs }

        created_def = EmbeddingDefinition.last

        expect(response.status).to eq(201)
        expect(created_def.display_name).to eq(valid_attrs[:display_name])
        expect(created_def.embed_prompt).to eq(valid_attrs[:embed_prompt])
        expect(created_def.search_prompt).to eq(valid_attrs[:search_prompt])
        expect(created_def.matryoshka_dimensions).to eq(true)
      end

      it "logs the creation with StaffActionLogger" do
        expect {
          post "/admin/plugins/discourse-ai/ai-embeddings.json",
               params: {
                 ai_embedding: valid_attrs,
               }
        }.to change {
          UserHistory.where(
            action: UserHistory.actions[:custom_staff],
            custom_type: "create_ai_embedding",
          ).count
        }.by(1)

        history =
          UserHistory.where(
            action: UserHistory.actions[:custom_staff],
            custom_type: "create_ai_embedding",
          ).last
        expect(history.details).to include("display_name: Embedding config test")
        expect(history.details).to include("provider: hugging_face")
        expect(history.details).to include("dimensions: 1001")
        expect(history.subject).to eq("Embedding config test") # Verify subject field is included
      end

      it "stores provider-specific config params" do
        post "/admin/plugins/discourse-ai/ai-embeddings.json",
             params: {
               ai_embedding:
                 valid_attrs.merge(
                   provider: "open_ai",
                   provider_params: {
                     model_name: "embeddings-v1",
                   },
                 ),
             }

        created_def = EmbeddingDefinition.last

        expect(response.status).to eq(201)
        expect(created_def.provider_params["model_name"]).to eq("embeddings-v1")
      end

      it "ignores parameters not associated with that provider" do
        post "/admin/plugins/discourse-ai/ai-embeddings.json",
             params: {
               ai_embedding: valid_attrs.merge(provider_params: { custom: "custom" }),
             }

        created_def = EmbeddingDefinition.last

        expect(response.status).to eq(201)
        expect(created_def.lookup_custom_param("custom")).to be_nil
      end
    end

    context "with invalid attrs" do
      it "doesn't create a new embedding definition" do
        post "/admin/plugins/discourse-ai/ai-embeddings.json",
             params: {
               ai_embedding: valid_attrs.except(:provider),
             }

        created_def = EmbeddingDefinition.last

        expect(created_def).to be_nil
      end
    end
  end

  describe "PUT #update" do
    fab!(:embedding_definition)

    context "with valid update params" do
      let(:update_attrs) { { provider: "open_ai" } }

      it "updates the model" do
        put "/admin/plugins/discourse-ai/ai-embeddings/#{embedding_definition.id}.json",
            params: {
              ai_embedding: update_attrs,
            }

        expect(response.status).to eq(200)
        expect(embedding_definition.reload.provider).to eq(update_attrs[:provider])
      end

      it "logs the update with StaffActionLogger" do
        expect {
          put "/admin/plugins/discourse-ai/ai-embeddings/#{embedding_definition.id}.json",
              params: {
                ai_embedding: update_attrs,
              }
        }.to change {
          UserHistory.where(
            action: UserHistory.actions[:custom_staff],
            custom_type: "update_ai_embedding",
          ).count
        }.by(1)

        history =
          UserHistory.where(
            action: UserHistory.actions[:custom_staff],
            custom_type: "update_ai_embedding",
          ).last
        expect(history.details).to include("embedding_id: #{embedding_definition.id}")
        expect(history.subject).to eq(embedding_definition.display_name) # Verify subject field is included
      end

      it "returns a 404 if there is no model with the given Id" do
        put "/admin/plugins/discourse-ai/ai-embeddings/9999999.json"

        expect(response.status).to eq(404)
      end

      it "doesn't allow dimensions to be updated" do
        new_dimensions = 200

        put "/admin/plugins/discourse-ai/ai-embeddings/#{embedding_definition.id}.json",
            params: {
              ai_embedding: {
                dimensions: new_dimensions,
              },
            }

        expect(response.status).to eq(200)
        expect(embedding_definition.reload.dimensions).not_to eq(new_dimensions)
      end
    end

    context "with invalid update params" do
      it "doesn't update the model" do
        put "/admin/plugins/discourse-ai/ai-embeddings/#{embedding_definition.id}.json",
            params: {
              ai_embedding: {
                url: "",
              },
            }

        expect(response.status).to eq(422)
      end
    end
  end

  describe "DELETE #destroy" do
    fab!(:embedding_definition)

    it "destroys the embedding definition" do
      expect {
        delete "/admin/plugins/discourse-ai/ai-embeddings/#{embedding_definition.id}.json"

        expect(response).to have_http_status(:no_content)
      }.to change(EmbeddingDefinition, :count).by(-1)
    end

    it "logs the deletion with StaffActionLogger" do
      embedding_id = embedding_definition.id
      display_name = embedding_definition.display_name

      expect {
        delete "/admin/plugins/discourse-ai/ai-embeddings/#{embedding_definition.id}.json"
      }.to change {
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "delete_ai_embedding",
        ).count
      }.by(1)

      history =
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "delete_ai_embedding",
        ).last
      expect(history.details).to include("embedding_id: #{embedding_id}")
      expect(history.details).to include("display_name: #{display_name}")
      expect(history.subject).to eq(display_name) # Verify subject field is included
    end

    it "validates the model is not in use" do
      SiteSetting.ai_embeddings_selected_model = embedding_definition.id

      delete "/admin/plugins/discourse-ai/ai-embeddings/#{embedding_definition.id}.json"

      expect(response.status).to eq(409)
      expect(embedding_definition.reload).to eq(embedding_definition)
    end
  end

  describe "GET #test" do
    context "when we can generate an embedding" do
      it "returns a success true flag" do
        WebMock.stub_request(:post, valid_attrs[:url]).to_return(status: 200, body: [[1]].to_json)

        get "/admin/plugins/discourse-ai/ai-embeddings/test.json",
            params: {
              ai_embedding: valid_attrs,
            }

        expect(response).to be_successful
        expect(response.parsed_body["success"]).to eq(true)
      end
    end

    context "when we cannot generate an embedding" do
      it "returns a success false flag and the error message" do
        error_message = { error: "Embedding generation failed." }

        WebMock.stub_request(:post, valid_attrs[:url]).to_return(
          status: 422,
          body: error_message.to_json,
        )

        get "/admin/plugins/discourse-ai/ai-embeddings/test.json",
            params: {
              ai_embedding: valid_attrs,
            }

        expect(response).to be_successful
        expect(response.parsed_body["success"]).to eq(false)
        expect(response.parsed_body["error"]).to eq(error_message.to_json)
      end
    end
  end
end
