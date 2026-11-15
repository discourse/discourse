# frozen_string_literal: true

RSpec.describe DiscourseAi::AiModeration::DsaClassificationsController do
  fab!(:moderator)
  fab!(:decision_model) { Fabricate(:decision_model, id: -1) }
  fab!(:reviewable, :reviewable_flagged_post)

  let(:rules) do
    [
      { ground: "Be respectful", explanation: "Personal attacks are not allowed." },
      { ground: "No advertising", explanation: "Unsolicited advertising is not allowed." },
    ]
  end
  let(:answers) do
    {
      community_rule: "No advertising: Unsolicited advertising is not allowed.",
      category: "Scams and fraud",
    }
  end

  let(:refusal_response) do
    { answers: { community_rule: { type: "refusal" }, category: { type: "refusal" } } }.to_json
  end

  before do
    enable_current_plugin
    enable_dsa_reporting(community_rules: rules)
    SiteSetting.ai_dsa_classification_decision_model = decision_model.id
  end

  describe "#suggest" do
    it "requires a login" do
      post "/discourse-ai/ai-moderation/dsa-classifications/#{reviewable.id}/suggest.json"

      expect(response.status).to eq(403)
    end

    it "denies users who cannot see the review queue" do
      sign_in(Fabricate(:user))

      post "/discourse-ai/ai-moderation/dsa-classifications/#{reviewable.id}/suggest.json"

      expect(response.status).to eq(403)
    end

    context "when signed in as staff" do
      before { sign_in(moderator) }

      it "returns the suggested classification on a localized site" do
        moderator.update!(locale: "de")
        TranslationOverride.upsert!(
          "de",
          "dsa_statements.categories.STATEMENT_CATEGORY_SCAMS_AND_FRAUD",
          "Betrug",
        )

        DiscourseAi::Decisions.with_canned_answers(**answers) do
          post "/discourse-ai/ai-moderation/dsa-classifications/#{reviewable.id}/suggest.json"
        end

        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq(
          "community_rule" =>
            DsaStatementOfRecord.community_rules.find { |rule| rule["ground"] == "No advertising" }[
              "id"
            ],
          "category" => "STATEMENT_CATEGORY_SCAMS_AND_FRAUD",
        )
      end

      it "returns blank fields when the model cannot suggest a classification" do
        stub_request(:post, decision_model.url).to_return(body: refusal_response)

        post "/discourse-ai/ai-moderation/dsa-classifications/#{reviewable.id}/suggest.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq("community_rule" => nil, "category" => nil)
        expect(AiApiAuditLog.last).to have_attributes(
          user_id: moderator.id,
          feature_name: "dsa_classification",
        )
      end

      it "returns not found for an unknown reviewable" do
        post "/discourse-ai/ai-moderation/dsa-classifications/0/suggest.json"

        expect(response.status).to eq(404)
      end

      it "returns not found for a reviewable the moderator cannot see" do
        hidden = Fabricate(:reviewable_flagged_post, reviewable_by_moderator: false)

        post "/discourse-ai/ai-moderation/dsa-classifications/#{hidden.id}/suggest.json"

        expect(response.status).to eq(404)
      end

      it "denies access without a decision model" do
        SiteSetting.ai_dsa_classification_decision_model = ""

        post "/discourse-ai/ai-moderation/dsa-classifications/#{reviewable.id}/suggest.json"

        expect(response.status).to eq(403)
      end

      it "denies access when DSA reporting is disabled" do
        SiteSetting.dsa_reporting_enabled = false

        post "/discourse-ai/ai-moderation/dsa-classifications/#{reviewable.id}/suggest.json"

        expect(response.status).to eq(403)
      end

      it "returns an error when the decision request fails" do
        stub_request(:post, decision_model.url).to_return(status: 400, body: "{}")

        post "/discourse-ai/ai-moderation/dsa-classifications/#{reviewable.id}/suggest.json"

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to contain_exactly(
          I18n.t("discourse_ai.dsa_classification.suggestion_failed"),
        )
      end

      it "returns too many requests when the decision model is out of credits" do
        Fabricate(:decision_model_credit_allocation, decision_model:, daily_used: 10_000)

        post "/discourse-ai/ai-moderation/dsa-classifications/#{reviewable.id}/suggest.json"

        expect(response.status).to eq(429)
        expect(response.parsed_body["errors"]).to contain_exactly(
          I18n.t("discourse_ai.dsa_classification.credit_limit_exceeded"),
        )
      end

      it "sends the flagged content even after the post is deleted" do
        flagged_post = reviewable.target
        flagged_post.update!(raw: "Tom & Jerry > other deals.")
        flagged_post.trash!
        stub_request(:post, decision_model.url).to_return(body: refusal_response)

        post "/discourse-ai/ai-moderation/dsa-classifications/#{reviewable.id}/suggest.json"

        expect(response.status).to eq(200)
        provider_context = JSON.parse(AiApiAuditLog.last.raw_request_payload).fetch("state")
        expect(provider_context).to include(flagged_post.raw, "Inappropriate")
      end

      it "sends queued post content without the original email" do
        queued_post = Fabricate(:reviewable_queued_post)
        stub_request(:post, decision_model.url).to_return(body: refusal_response)

        post "/discourse-ai/ai-moderation/dsa-classifications/#{queued_post.id}/suggest.json"

        expect(response.status).to eq(200)
        expect(AiApiAuditLog.last.raw_request_payload).to include(queued_post.payload["raw"])
        expect(AiApiAuditLog.last.raw_request_payload).not_to include(
          queued_post.payload["raw_email"],
        )
      end

      it "sends public profile content without account details" do
        user = Fabricate(:user, email: "private-email@example.com", ip_address: "198.51.100.25")
        user.user_profile.update!(bio_raw: "Buy discounted watches from my shop.")
        profile_review =
          Fabricate(:reviewable_user, target: user, payload: ReviewableUser.payload_for(user))
        stub_request(:post, decision_model.url).to_return(body: refusal_response)

        post "/discourse-ai/ai-moderation/dsa-classifications/#{profile_review.id}/suggest.json"

        expect(response.status).to eq(200)
        expect(AiApiAuditLog.last.raw_request_payload).to include(user.user_profile.bio_raw)
        expect(AiApiAuditLog.last.raw_request_payload).not_to include(
          user.email,
          user.ip_address.to_s,
        )
      end

      it "sends the content of a chat reviewable" do
        message = Fabricate(:chat_message, message: "Buy discounted watches from my shop.")
        chat_review = Fabricate(:chat_reviewable_message, target: message)
        stub_request(:post, decision_model.url).to_return(body: refusal_response)

        post "/discourse-ai/ai-moderation/dsa-classifications/#{chat_review.id}/suggest.json"

        expect(response.status).to eq(200)
        expect(AiApiAuditLog.last.raw_request_payload).to include(message.message)
      end

      it "limits the content sent to the model" do
        reviewable.target.update_columns(raw: "a" * 10_000)
        stub_request(:post, decision_model.url).to_return(body: refusal_response)

        post "/discourse-ai/ai-moderation/dsa-classifications/#{reviewable.id}/suggest.json"

        expect(response.status).to eq(200)
        expect(JSON.parse(AiApiAuditLog.last.raw_request_payload).fetch("state").length).to be <=
          6000
      end

      it "returns no suggestion when the reviewable has no readable content" do
        empty_review = Fabricate(:reviewable_user, payload: {})

        post "/discourse-ai/ai-moderation/dsa-classifications/#{empty_review.id}/suggest.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq("community_rule" => nil, "category" => nil)
        expect(a_request(:post, decision_model.url)).not_to have_been_made
      end

      it "suggests a category when only one community rule is configured" do
        enable_dsa_reporting(community_rules: [rules.last])

        DiscourseAi::Decisions.with_canned_answers(category: "Scams and fraud") do
          post "/discourse-ai/ai-moderation/dsa-classifications/#{reviewable.id}/suggest.json"
        end

        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq(
          "community_rule" => DsaStatementOfRecord.community_rules.sole["id"],
          "category" => "STATEMENT_CATEGORY_SCAMS_AND_FRAUD",
        )
      end

      it "returns the selected rule when two rules have the same combined label" do
        enable_dsa_reporting(
          community_rules: [
            { ground: "Advertising", explanation: "Spam: unsolicited promotions" },
            { ground: "Advertising: Spam", explanation: "unsolicited promotions" },
          ],
        )

        DiscourseAi::Decisions.with_canned_answers(
          community_rule: "1. Advertising: Spam: unsolicited promotions",
          category: "Scams and fraud",
        ) { post "/discourse-ai/ai-moderation/dsa-classifications/#{reviewable.id}/suggest.json" }

        expect(response.status).to eq(200)
        expect(response.parsed_body["community_rule"]).to eq(
          DsaStatementOfRecord.community_rules.first["id"],
        )
      end

      it "rate limits suggestions" do
        RateLimiter.enable
        stub_const(described_class, :SUGGESTIONS_PER_MINUTE, 1) do
          DiscourseAi::Decisions.with_canned_answers(**answers) do
            post "/discourse-ai/ai-moderation/dsa-classifications/#{reviewable.id}/suggest.json"

            expect(response.status).to eq(200)

            post "/discourse-ai/ai-moderation/dsa-classifications/#{reviewable.id}/suggest.json"
          end
        end

        expect(response.status).to eq(429)
      end
    end
  end
end
