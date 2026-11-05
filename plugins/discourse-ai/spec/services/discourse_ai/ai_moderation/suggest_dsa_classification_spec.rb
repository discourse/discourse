# frozen_string_literal: true

RSpec.describe DiscourseAi::AiModeration::SuggestDsaClassification do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:reviewable_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :moderator)
    fab!(:decision_model)
    fab!(:reviewable, :reviewable_flagged_post)

    let(:params) { { reviewable_id: } }
    let(:dependencies) { { guardian: acting_user.guardian } }
    let(:reviewable_id) { reviewable.id }
    let(:rules) do
      [
        { ground: "Be respectful", explanation: "Personal attacks are not allowed." },
        { ground: "No advertising", explanation: "Unsolicited advertising is not allowed." },
      ]
    end
    let(:advertising_rule_id) do
      DsaStatementOfRecord.community_rules.find { |rule| rule["ground"] == "No advertising" }["id"]
    end

    before do
      enable_current_plugin
      enable_dsa_reporting(community_rules: rules)
      SiteSetting.ai_dsa_classification_decision_model = decision_model.id
    end

    context "when contract is invalid" do
      let(:reviewable_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when DSA classification is disabled" do
      before { SiteSetting.dsa_reporting_enabled = false }

      it { is_expected.to fail_a_policy(:classification_enabled) }
    end

    context "without a decision model" do
      before { SiteSetting.ai_dsa_classification_decision_model = "" }

      it { is_expected.to fail_to_find_a_model(:decision_model) }
    end

    context "when the reviewable does not exist" do
      let(:reviewable_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:reviewable) }
    end

    context "when the user cannot see the reviewable" do
      fab!(:acting_user, :user)

      it { is_expected.to fail_to_find_a_model(:reviewable) }
    end

    context "when the decision fails" do
      before { stub_request(:post, decision_model.url).to_return(status: 400, body: "{}") }

      it { is_expected.to fail_to_find_a_model(:suggestion) }

      it "exposes the decision error" do
        expect(result[:"result.model.suggestion"].exception).to be_a(
          DiscourseAi::Decisions::RequestFailed,
        )
      end
    end

    context "when everything's ok" do
      around do |example|
        DiscourseAi::Decisions.with_canned_answers(
          community_rule: "No advertising: Unsolicited advertising is not allowed.",
          category: "Scams and fraud",
        ) { example.run }
      end

      it { is_expected.to run_successfully }

      it "suggests the classification" do
        expect(result.suggestion).to eq(
          DiscourseAi::AiModeration::DsaClassification::Suggestion.new(
            community_rule: advertising_rule_id,
            category: "STATEMENT_CATEGORY_SCAMS_AND_FRAUD",
          ),
        )
      end

      it "asks the decision model on behalf of the acting user" do
        result

        expect(DiscourseAi::Decisions::CannedAnswers.current.calls).to contain_exactly(
          a_hash_including(feature_name: "dsa_classification", user: acting_user),
        )
      end
    end
  end
end
