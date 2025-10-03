# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiLlmsController do
  fab!(:admin)

  before do
    enable_current_plugin
    sign_in(admin)
    SiteSetting.ai_bot_enabled = true
  end

  describe "GET #index" do
    fab!(:llm_model) { Fabricate(:llm_model, enabled_chat_bot: true) }
    fab!(:llm_model2) { Fabricate(:llm_model) }
    fab!(:ai_persona) do
      Fabricate(
        :ai_persona,
        name: "Cool persona",
        force_default_llm: true,
        default_llm_id: llm_model2.id,
      )
    end

    fab!(:group)
    fab!(:quota) { Fabricate(:llm_quota, llm_model: llm_model, group: group) }
    fab!(:quota2) { Fabricate(:llm_quota, llm_model: llm_model, group: Fabricate(:group)) }

    it "includes quotas in serialized response" do
      get "/admin/plugins/discourse-ai/ai-llms.json"

      expect(response.status).to eq(200)

      llms = response.parsed_body["ai_llms"]
      expect(llms.length).to eq(2)

      model = llms.find { |m| m["id"] == llm_model.id }
      expect(model["llm_quotas"]).to be_present
      expect(model["llm_quotas"].length).to eq(2)
      expect(model["llm_quotas"].map { |q| q["id"] }).to contain_exactly(quota.id, quota2.id)
    end

    it "includes all available providers metadata" do
      get "/admin/plugins/discourse-ai/ai-llms.json"
      expect(response).to be_successful

      expect(response.parsed_body["meta"]["providers"]).to contain_exactly(
        *DiscourseAi::Completions::Llm.provider_names,
      )
    end

    it "lists enabled features on appropriate LLMs" do
      SiteSetting.ai_bot_enabled = true
      fake_model = assign_fake_provider_to(:ai_default_llm_model)

      # setting the setting calls the model
      DiscourseAi::Completions::Llm.with_prepared_responses(["OK"]) do
        SiteSetting.ai_helper_proofreader_persona = ai_persona.id
        SiteSetting.ai_helper_enabled = true
      end

      DiscourseAi::Completions::Llm.with_prepared_responses(["OK"]) do
        SiteSetting.ai_summarization_enabled = true
      end

      DiscourseAi::Completions::Llm.with_prepared_responses(["OK"]) do
        SiteSetting.ai_embeddings_semantic_search_enabled = true
      end

      get "/admin/plugins/discourse-ai/ai-llms.json"

      llms = response.parsed_body["ai_llms"]

      model_json = llms.find { |m| m["id"] == llm_model.id }
      expect(model_json["used_by"]).to contain_exactly({ "type" => "ai_bot" })

      model2_json = llms.find { |m| m["id"] == llm_model2.id }

      expect(model2_json["used_by"]).to contain_exactly(
        { "type" => "ai_persona", "name" => "Cool persona", "id" => ai_persona.id },
        { "type" => "ai_helper", "name" => "Proofread text" },
      )

      model3_json = llms.find { |m| m["id"] == fake_model.id }

      expect(model3_json["used_by"]).to contain_exactly(
        { "type" => "ai_summarization" },
        { "type" => "ai_embeddings_semantic_search" },
      )
    end
  end

  describe "POST #create" do
    let(:valid_attrs) do
      {
        display_name: "My cool LLM",
        name: "gpt-3.5",
        provider: "open_ai",
        url: "https://test.test/v1/chat/completions",
        api_key: "test",
        tokenizer: "DiscourseAi::Tokenizer::OpenAiTokenizer",
        max_prompt_tokens: 16_000,
      }
    end

    context "with quotas" do
      let(:group) { Fabricate(:group) }
      let(:quota_params) do
        [{ group_id: group.id, max_tokens: 1000, max_usages: 10, duration_seconds: 86_400 }]
      end

      it "creates model with quotas" do
        post "/admin/plugins/discourse-ai/ai-llms.json",
             params: {
               ai_llm: valid_attrs.merge(llm_quotas: quota_params),
             }

        expect(response.status).to eq(201)
        created_model = LlmModel.last
        expect(created_model.llm_quotas.count).to eq(1)
        quota = created_model.llm_quotas.first
        expect(quota.max_tokens).to eq(1000)
        expect(quota.group_id).to eq(group.id)
      end
    end

    context "with valid attributes" do
      it "creates a new LLM model" do
        post "/admin/plugins/discourse-ai/ai-llms.json", params: { ai_llm: valid_attrs }
        response_body = response.parsed_body

        created_model = response_body["ai_llm"]

        expect(created_model["display_name"]).to eq(valid_attrs[:display_name])
        expect(created_model["name"]).to eq(valid_attrs[:name])
        expect(created_model["provider"]).to eq(valid_attrs[:provider])
        expect(created_model["tokenizer"]).to eq(valid_attrs[:tokenizer])
        expect(created_model["max_prompt_tokens"]).to eq(valid_attrs[:max_prompt_tokens])

        model = LlmModel.find(created_model["id"])
        expect(model.display_name).to eq(valid_attrs[:display_name])
      end

      it "logs staff action when creating an LLM model" do
        # Log the creation
        post "/admin/plugins/discourse-ai/ai-llms.json", params: { ai_llm: valid_attrs }
        expect(response.status).to eq(201)

        # Now verify the log was created with the right subject
        history =
          UserHistory.where(
            action: UserHistory.actions[:custom_staff],
            custom_type: "create_ai_llm_model",
          ).last
        expect(history).to be_present
        expect(history.subject).to eq(valid_attrs[:display_name]) # Verify subject is set to display_name
      end

      it "creates a companion user" do
        post "/admin/plugins/discourse-ai/ai-llms.json",
             params: {
               ai_llm: valid_attrs.merge(enabled_chat_bot: true),
             }

        created_model = LlmModel.last

        expect(created_model.user_id).to be_present
      end

      it "stores provider-specific config params" do
        provider_params = { organization: "Discourse" }

        post "/admin/plugins/discourse-ai/ai-llms.json",
             params: {
               ai_llm: valid_attrs.merge(provider_params: provider_params),
             }

        created_model = LlmModel.last

        expect(created_model.lookup_custom_param("organization")).to eq(
          provider_params[:organization],
        )
      end

      it "ignores parameters not associated with that provider" do
        provider_params = { access_key_id: "random_key" }

        post "/admin/plugins/discourse-ai/ai-llms.json",
             params: {
               ai_llm: valid_attrs.merge(provider_params: provider_params),
             }

        created_model = LlmModel.last

        expect(created_model.lookup_custom_param("access_key_id")).to be_nil
      end
    end

    context "with invalid attributes" do
      it "doesn't create a model" do
        post "/admin/plugins/discourse-ai/ai-llms.json",
             params: {
               ai_llm: valid_attrs.except(:url),
             }

        created_model = LlmModel.last

        expect(created_model).to be_nil
      end
    end

    context "with provider-specific params" do
      it "doesn't create a model if a Bedrock param is missing" do
        post "/admin/plugins/discourse-ai/ai-llms.json",
             params: {
               ai_llm:
                 valid_attrs.merge(
                   provider: "aws_bedrock",
                   provider_params: {
                     region: "us-east-1",
                   },
                 ),
             }

        created_model = LlmModel.last

        expect(response.status).to eq(422)
        expect(created_model).to be_nil
      end

      it "creates the model if all required provider params are present" do
        post "/admin/plugins/discourse-ai/ai-llms.json",
             params: {
               ai_llm:
                 valid_attrs.merge(
                   provider: "aws_bedrock",
                   provider_params: {
                     region: "us-east-1",
                     access_key_id: "test",
                   },
                 ),
             }

        created_model = LlmModel.last

        expect(response.status).to eq(201)
        expect(created_model.lookup_custom_param("region")).to eq("us-east-1")
        expect(created_model.lookup_custom_param("access_key_id")).to eq("test")
      end

      it "supports boolean values" do
        post "/admin/plugins/discourse-ai/ai-llms.json",
             params: {
               ai_llm:
                 valid_attrs.merge(
                   provider: "vllm",
                   provider_params: {
                     disable_system_prompt: true,
                   },
                 ),
             }

        created_model = LlmModel.last

        expect(response.status).to eq(201)
        expect(created_model.lookup_custom_param("disable_system_prompt")).to eq(true)
      end
    end
  end

  describe "PUT #update" do
    fab!(:llm_model)

    context "with valid update params" do
      let(:update_attrs) { { provider: "anthropic" } }

      context "with quotas" do
        it "updates quotas correctly" do
          group1 = Fabricate(:group)
          group2 = Fabricate(:group)
          group3 = Fabricate(:group)

          _quota1 =
            Fabricate(
              :llm_quota,
              llm_model: llm_model,
              group: group1,
              max_tokens: 1000,
              max_usages: 10,
              duration_seconds: 86_400,
            )
          _quota2 =
            Fabricate(
              :llm_quota,
              llm_model: llm_model,
              group: group2,
              max_tokens: 2000,
              max_usages: 20,
              duration_seconds: 86_400,
            )

          put "/admin/plugins/discourse-ai/ai-llms/#{llm_model.id}.json",
              params: {
                ai_llm: {
                  llm_quotas: [
                    {
                      group_id: group1.id,
                      max_tokens: 1500,
                      max_usages: 15,
                      duration_seconds: 43_200,
                    },
                    {
                      group_id: group3.id,
                      max_tokens: 3000,
                      max_usages: 30,
                      duration_seconds: 86_400,
                    },
                  ],
                },
              }

          expect(response.status).to eq(200)

          llm_model.reload
          expect(llm_model.llm_quotas.count).to eq(2)

          updated_quota1 = llm_model.llm_quotas.find_by(group: group1)
          expect(updated_quota1.max_tokens).to eq(1500)
          expect(updated_quota1.max_usages).to eq(15)
          expect(updated_quota1.duration_seconds).to eq(43_200)

          expect(llm_model.llm_quotas.find_by(group: group2)).to be_nil

          new_quota = llm_model.llm_quotas.find_by(group: group3)
          expect(new_quota).to be_present
          expect(new_quota.max_tokens).to eq(3000)
          expect(new_quota.max_usages).to eq(30)
          expect(new_quota.duration_seconds).to eq(86_400)
        end
      end

      it "updates the model" do
        put "/admin/plugins/discourse-ai/ai-llms/#{llm_model.id}.json",
            params: {
              ai_llm: update_attrs,
            }

        expect(response.status).to eq(200)
        expect(llm_model.reload.provider).to eq(update_attrs[:provider])
      end

      it "logs staff action when updating an LLM model" do
        # The initial provider is different from the update
        original_provider = llm_model.provider
        display_name = llm_model.display_name

        # Perform the update
        put "/admin/plugins/discourse-ai/ai-llms/#{llm_model.id}.json",
            params: {
              ai_llm: update_attrs,
            }

        expect(response.status).to eq(200)

        # Now verify the log was created with the right subject
        history =
          UserHistory.where(
            action: UserHistory.actions[:custom_staff],
            custom_type: "update_ai_llm_model",
          ).last
        expect(history).to be_present
        expect(history.subject).to eq(display_name) # Verify subject is set to display_name
      end

      it "returns a 404 if there is no model with the given Id" do
        put "/admin/plugins/discourse-ai/ai-llms/9999999.json"

        expect(response.status).to eq(404)
      end

      it "creates a companion user" do
        put "/admin/plugins/discourse-ai/ai-llms/#{llm_model.id}.json",
            params: {
              ai_llm: update_attrs.merge(enabled_chat_bot: true),
            }

        expect(llm_model.reload.user_id).to be_present
      end

      it "removes the companion user when desabling the chat bot option" do
        llm_model.update!(enabled_chat_bot: true)
        llm_model.toggle_companion_user

        put "/admin/plugins/discourse-ai/ai-llms/#{llm_model.id}.json",
            params: {
              ai_llm: update_attrs.merge(enabled_chat_bot: false),
            }

        expect(llm_model.reload.user_id).to be_nil
      end
    end

    context "with invalid update params" do
      it "doesn't update the model" do
        put "/admin/plugins/discourse-ai/ai-llms/#{llm_model.id}.json",
            params: {
              ai_llm: {
                url: "",
              },
            }

        expect(response.status).to eq(422)
      end
    end

    context "with provider-specific params" do
      it "updates provider-specific config params" do
        provider_params = { organization: "Discourse" }

        put "/admin/plugins/discourse-ai/ai-llms/#{llm_model.id}.json",
            params: {
              ai_llm: {
                provider_params: provider_params,
              },
            }

        expect(llm_model.reload.lookup_custom_param("organization")).to eq(
          provider_params[:organization],
        )
      end

      it "ignores parameters not associated with that provider" do
        provider_params = { access_key_id: "random_key" }

        put "/admin/plugins/discourse-ai/ai-llms/#{llm_model.id}.json",
            params: {
              ai_llm: {
                provider_params: provider_params,
              },
            }

        expect(llm_model.reload.lookup_custom_param("access_key_id")).to be_nil
      end
    end
  end

  describe "GET #test" do
    let(:test_attrs) do
      {
        name: "llama3",
        provider: "hugging_face",
        url: "https://test.test/v1/chat/completions",
        api_key: "test",
        tokenizer: "DiscourseAi::Tokenizer::Llama3Tokenizer",
        max_prompt_tokens: 2_000,
      }
    end

    context "when we can contact the model" do
      it "returns a success true flag" do
        DiscourseAi::Completions::Llm.with_prepared_responses(["a response"]) do
          get "/admin/plugins/discourse-ai/ai-llms/test.json", params: { ai_llm: test_attrs }

          expect(response).to be_successful
          expect(response.parsed_body["success"]).to eq(true)
        end
      end
    end

    context "when we cannot contact the model" do
      it "returns a success false flag and the error message" do
        error_message = {
          error:
            "Input validation error: `inputs` tokens + `max_new_tokens` must be <= 1512. Given: 30 `inputs` tokens and 3984 `max_new_tokens`",
          error_type: "validation",
        }

        error =
          DiscourseAi::Completions::Endpoints::Base::CompletionFailed.new(error_message.to_json)

        DiscourseAi::Completions::Llm.with_prepared_responses([error]) do
          get "/admin/plugins/discourse-ai/ai-llms/test.json", params: { ai_llm: test_attrs }

          expect(response).to be_successful
          expect(response.parsed_body["success"]).to eq(false)
          expect(response.parsed_body["error"]).to eq(error_message.to_json)
        end
      end
    end

    context "when config is invalid" do
      it "returns a success false with the validation error" do
        get "/admin/plugins/discourse-ai/ai-llms/test.json",
            params: {
              ai_llm: test_attrs.except(:max_prompt_tokens),
            }

        expect(response).to be_successful
        expect(response.parsed_body["success"]).to eq(false)
        expect(response.parsed_body["validation_errors"]).to contain_exactly(
          "Context window is not a number",
        )
      end
    end
  end

  describe "DELETE #destroy" do
    fab!(:llm_model)

    it "destroys the requested ai_persona" do
      expect {
        delete "/admin/plugins/discourse-ai/ai-llms/#{llm_model.id}.json"

        expect(response).to have_http_status(:no_content)
      }.to change(LlmModel, :count).by(-1)
    end

    it "logs staff action when deleting an LLM model" do
      # Capture the model details before deletion for comparison
      model_display_name = llm_model.display_name

      # Delete the model
      delete "/admin/plugins/discourse-ai/ai-llms/#{llm_model.id}.json"
      expect(response).to have_http_status(:no_content)

      # Now verify the log was created with the right subject
      history =
        UserHistory.where(
          action: UserHistory.actions[:custom_staff],
          custom_type: "delete_ai_llm_model",
        ).last
      expect(history).to be_present
      expect(history.subject).to eq(model_display_name) # Verify subject is set to display_name
    end

    context "with llms configured" do
      fab!(:ai_persona) { Fabricate(:ai_persona, default_llm_id: llm_model.id) }

      before { assign_fake_provider_to(:ai_helper_model) }
      it "validates the model is not in use" do
        delete "/admin/plugins/discourse-ai/ai-llms/#{llm_model.id}.json"
        expect(response.status).to eq(409)
        expect(llm_model.reload).to eq(llm_model)
      end
    end

    it "cleans up companion users before deleting the model" do
      llm_model.update!(enabled_chat_bot: true)
      llm_model.toggle_companion_user
      companion_user = llm_model.user

      delete "/admin/plugins/discourse-ai/ai-llms/#{llm_model.id}.json"

      expect { companion_user.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
