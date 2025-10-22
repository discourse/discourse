# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiSpamController do
  fab!(:admin)
  fab!(:user)
  fab!(:llm_model)

  before { enable_current_plugin }

  describe "#update" do
    context "when logged in as admin" do
      before { sign_in(admin) }

      it "can update settings from scratch" do
        put "/admin/plugins/discourse-ai/ai-spam.json",
            params: {
              is_enabled: true,
              llm_model_id: llm_model.id,
              ai_persona_id:
                DiscourseAi::Personas::Persona.system_personas[DiscourseAi::Personas::SpamDetector],
              custom_instructions: "custom instructions",
            }

        expect(response.status).to eq(200)
        expect(SiteSetting.ai_spam_detection_enabled).to eq(true)
        expect(AiModerationSetting.spam.llm_model_id).to eq(llm_model.id)
        expect(AiModerationSetting.spam.ai_persona_id).to eq(
          DiscourseAi::Personas::Persona.system_personas[DiscourseAi::Personas::SpamDetector],
        )
        expect(AiModerationSetting.spam.data["custom_instructions"]).to eq("custom instructions")
      end

      it "validates the selected persona has a valid response format" do
        ai_persona = Fabricate(:ai_persona, response_format: nil)

        put "/admin/plugins/discourse-ai/ai-spam.json",
            params: {
              is_enabled: true,
              llm_model_id: llm_model.id,
              ai_persona_id: ai_persona.id,
              custom_instructions: "custom instructions",
            }

        expect(response.status).to eq(422)

        ai_persona.update!(response_format: [{ "key" => "spam", "type" => "boolean" }])

        put "/admin/plugins/discourse-ai/ai-spam.json",
            params: {
              is_enabled: true,
              llm_model_id: llm_model.id,
              ai_persona_id: ai_persona.id,
              custom_instructions: "custom instructions",
            }

        expect(response.status).to eq(200)
        expect(AiModerationSetting.spam.ai_persona_id).to eq(ai_persona.id)
      end

      it "can not enable spam detection without a model selected" do
        put "/admin/plugins/discourse-ai/ai-spam.json",
            params: {
              custom_instructions: "custom instructions",
            }
        expect(response.status).to eq(422)
      end

      it "can not fiddle with custom instructions without an llm" do
        put "/admin/plugins/discourse-ai/ai-spam.json", params: { is_enabled: true }
        expect(response.status).to eq(422)
      end

      context "when spam detection was already set" do
        fab!(:setting) do
          AiModerationSetting.create(
            {
              setting_type: :spam,
              llm_model_id: llm_model.id,
              data: {
                custom_instructions: "custom instructions",
              },
            },
          )
        end

        it "can partially update settings" do
          put "/admin/plugins/discourse-ai/ai-spam.json", params: { is_enabled: false }

          expect(response.status).to eq(200)
          expect(SiteSetting.ai_spam_detection_enabled).to eq(false)
          expect(AiModerationSetting.spam.llm_model_id).to eq(llm_model.id)
          expect(AiModerationSetting.spam.data["custom_instructions"]).to eq("custom instructions")
        end

        it "can update pre existing settings" do
          put "/admin/plugins/discourse-ai/ai-spam.json",
              params: {
                is_enabled: true,
                llm_model_id: llm_model.id,
                custom_instructions: "custom instructions new",
              }

          expect(response.status).to eq(200)
          expect(SiteSetting.ai_spam_detection_enabled).to eq(true)
          expect(AiModerationSetting.spam.llm_model_id).to eq(llm_model.id)
          expect(AiModerationSetting.spam.data["custom_instructions"]).to eq(
            "custom instructions new",
          )
        end

        it "logs staff action when custom_instructions change" do
          put "/admin/plugins/discourse-ai/ai-spam.json",
              params: {
                is_enabled: true,
                llm_model_id: llm_model.id,
                custom_instructions: "updated instructions",
              }

          expect(response.status).to eq(200)

          history =
            UserHistory.where(
              action: UserHistory.actions[:custom_staff],
              custom_type: "update_ai_spam_settings",
            ).last
          expect(history).to be_present
          expect(history.details).to include("custom_instructions")
        end

        it "logs staff action when llm_model_id changes" do
          # Create another model to change to
          new_llm_model =
            Fabricate(:llm_model, name: "New Test Model", display_name: "New Test Model")

          put "/admin/plugins/discourse-ai/ai-spam.json", params: { llm_model_id: new_llm_model.id }

          expect(response.status).to eq(200)

          # Verify the log was created with the right subject
          history =
            UserHistory.where(
              action: UserHistory.actions[:custom_staff],
              custom_type: "update_ai_spam_settings",
            ).last
          expect(history).to be_present
          expect(history.details).to include("llm_model_id")
        end

        it "logs staff actio when ai_persona_id changes" do
          new_persona =
            Fabricate(
              :ai_persona,
              name: "Updated Persona",
              response_format: [{ "key" => "spam", "type" => "boolean" }],
            )

          put "/admin/plugins/discourse-ai/ai-spam.json", params: { ai_persona_id: new_persona.id }

          expect(response.status).to eq(200)

          # Verify the log was created with the right subject
          history =
            UserHistory.where(
              action: UserHistory.actions[:custom_staff],
              custom_type: "update_ai_spam_settings",
            ).last
          expect(history).to be_present
          expect(history.details).to include("ai_persona_id")
          expect(history.details).to include(new_persona.name)
        end

        it "does not log staff action when only is_enabled changes" do
          # Check initial count of logs
          initial_count =
            UserHistory.where(
              action: UserHistory.actions[:custom_staff],
              custom_type: "update_ai_spam_settings",
            ).count

          # Update only the is_enabled setting
          put "/admin/plugins/discourse-ai/ai-spam.json", params: { is_enabled: false }

          expect(response.status).to eq(200)

          # Verify no new log was created
          current_count =
            UserHistory.where(
              action: UserHistory.actions[:custom_staff],
              custom_type: "update_ai_spam_settings",
            ).count
          expect(current_count).to eq(initial_count)
        end

        it "logs both custom_instructions and llm_model_id changes in one entry" do
          # Create another model to change to
          new_llm_model =
            Fabricate(:llm_model, name: "Another Test Model", display_name: "Another Test Model")

          put "/admin/plugins/discourse-ai/ai-spam.json",
              params: {
                llm_model_id: new_llm_model.id,
                custom_instructions: "new instructions for both changes",
              }

          expect(response.status).to eq(200)

          # Verify the log was created with all changes
          history =
            UserHistory.where(
              action: UserHistory.actions[:custom_staff],
              custom_type: "update_ai_spam_settings",
            ).last
          expect(history).to be_present
          expect(history.details).to include("llm_model_id")
          expect(history.details).to include("custom_instructions")
        end
      end
    end
  end

  describe "#test" do
    fab!(:spam_post, :post)
    fab!(:spam_post2) { Fabricate(:post, topic: spam_post.topic, raw: "something special 123") }
    fab!(:setting) do
      AiModerationSetting.create(
        {
          setting_type: :spam,
          llm_model_id: llm_model.id,
          data: {
            custom_instructions: "custom instructions",
          },
        },
      )
    end

    before { sign_in(admin) }

    it "can scan using post url (even when trashed and user deleted)" do
      User.where(id: spam_post2.user_id).delete_all
      spam_post2.topic.trash!
      spam_post2.trash!

      llm2 = Fabricate(:llm_model, name: "DiffLLM")

      DiscourseAi::Completions::Llm.with_prepared_responses([true, "just because"]) do
        post "/admin/plugins/discourse-ai/ai-spam/test.json",
             params: {
               post_url: spam_post2.url,
               llm_id: llm2.id,
             }
      end

      expect(response.status).to eq(200)

      parsed = response.parsed_body
      expect(parsed["log"]).to include(spam_post2.raw)
      expect(parsed["log"]).to include("DiffLLM")
    end

    it "can scan using post id" do
      DiscourseAi::Completions::Llm.with_prepared_responses([true, "because apples"]) do
        post "/admin/plugins/discourse-ai/ai-spam/test.json",
             params: {
               post_url: spam_post.id.to_s,
             }
      end

      expect(response.status).to eq(200)

      parsed = response.parsed_body
      expect(parsed["log"]).to include(spam_post.raw)
    end

    it "returns proper spam test results" do
      freeze_time DateTime.parse("2000-01-01")

      AiSpamLog.create!(
        post: spam_post,
        llm_model: llm_model,
        is_spam: false,
        created_at: 2.days.ago,
      )

      AiSpamLog.create!(post: spam_post, llm_model: llm_model, is_spam: true, created_at: 1.day.ago)

      DiscourseAi::Completions::Llm.with_prepared_responses([true, "because banana"]) do
        post "/admin/plugins/discourse-ai/ai-spam/test.json",
             params: {
               post_url: spam_post.url,
               custom_instructions: "special custom instructions",
             }
      end

      expect(response.status).to eq(200)

      parsed = response.parsed_body
      expect(parsed["log"]).to include("special custom instructions")
      expect(parsed["log"]).to include(spam_post.raw)
      expect(parsed["is_spam"]).to eq(true)
      expect(parsed["log"]).to include("Scan History:")
      expect(parsed["log"]).to include("banana")
    end
  end

  describe "#show" do
    context "when logged in as admin" do
      before do
        sign_in(admin)
        AiModerationSetting.create!(setting_type: :spam, llm_model_id: llm_model.id)
      end

      it "lists available LLMs" do
        SiteSetting.ai_spam_detection_enabled = true
        Fabricate(:seeded_model)

        get "/admin/plugins/discourse-ai/ai-spam.json"
        expect(response.status).to eq(200)
        json = response.parsed_body

        expect(json["available_llms"].length).to eq(2)
      end

      it "returns the serialized spam settings" do
        SiteSetting.ai_spam_detection_enabled = true

        get "/admin/plugins/discourse-ai/ai-spam.json"

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["is_enabled"]).to eq(true)
        expect(json["selected_llm"]).to eq(nil)
        expect(json["custom_instructions"]).to eq(nil)
        expect(json["available_llms"]).to be_an(Array)
        expect(json["stats"]).to be_present
      end

      it "return proper settings when spam detection is enabled" do
        SiteSetting.ai_spam_detection_enabled = true

        AiModerationSetting.update!(
          {
            setting_type: :spam,
            llm_model_id: llm_model.id,
            data: {
              custom_instructions: "custom instructions",
            },
          },
        )

        flagging_user = DiscourseAi::AiModeration::SpamScanner.flagging_user
        expect(flagging_user.id).not_to eq(Discourse.system_user.id)

        AiSpamLog.create!(post_id: 1, llm_model_id: llm_model.id, is_spam: true, payload: "test")

        get "/admin/plugins/discourse-ai/ai-spam.json"

        json = response.parsed_body
        expect(json["is_enabled"]).to eq(true)
        expect(json["llm_id"]).to eq(llm_model.id)
        expect(json["custom_instructions"]).to eq("custom instructions")

        expect(json["stats"].to_h).to eq(
          "scanned_count" => 1,
          "spam_detected" => 1,
          "false_positives" => 0,
          "false_negatives" => 0,
        )

        expect(json["flagging_username"]).to eq(flagging_user.username)
      end
    end

    context "when not logged in as admin" do
      it "returns 404 for anonymous users" do
        get "/admin/plugins/discourse-ai/ai-spam.json"
        expect(response.status).to eq(404)
      end

      it "returns 404 for regular users" do
        sign_in(user)
        get "/admin/plugins/discourse-ai/ai-spam.json"
        expect(response.status).to eq(404)
      end
    end

    context "when plugin is disabled" do
      before do
        sign_in(admin)
        SiteSetting.discourse_ai_enabled = false
      end

      it "returns 404" do
        get "/admin/plugins/discourse-ai/ai-spam.json"
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#fix_errors" do
    fab!(:setting) do
      AiModerationSetting.create(
        {
          setting_type: :spam,
          llm_model_id: llm_model.id,
          data: {
            custom_instructions: "custom instructions",
          },
        },
      )
      fab!(:llm_model)

      before do
        sign_in(admin)
        DiscourseAi::AiModeration::SpamScanner.flagging_user.update!(admin: false)
      end

      it "resolves spam scanner not admin error" do
        post "/admin/plugins/discourse-ai/ai-spam/fix-errors",
             params: {
               error: "spam_scanner_not_admin",
             }

        expect(response.status).to eq(200)
        expect(DiscourseAi::AiModeration::SpamScanner.flagging_user.reload.admin).to eq(true)
      end

      it "returns an error when it can't update the user" do
        DiscourseAi::AiModeration::SpamScanner.flagging_user.destroy

        post "/admin/plugins/discourse-ai/ai-spam/fix-errors",
             params: {
               error: "spam_scanner_not_admin",
             }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to be_present
        expect(response.parsed_body["errors"].first).to eq(
          I18n.t("discourse_ai.spam_detection.bot_user_update_failed"),
        )
      end
    end
  end
end
