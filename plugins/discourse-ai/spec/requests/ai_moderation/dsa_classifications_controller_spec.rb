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

      it "returns the suggested classification" do
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

      it "returns blank fields the decision model refused" do
        DiscourseAi::Decisions.with_canned_answers(community_rule: :refusal, category: :refusal) do
          post "/discourse-ai/ai-moderation/dsa-classifications/#{reviewable.id}/suggest.json"
        end

        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq("community_rule" => nil, "category" => nil)
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

      it "does not hide unexpected errors as failed decisions" do
        allow_any_instance_of(DecisionModel).to receive(:decide).and_raise(ArgumentError, "bug")

        post "/discourse-ai/ai-moderation/dsa-classifications/#{reviewable.id}/suggest.json"

        expect(response.status).to eq(500)
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
