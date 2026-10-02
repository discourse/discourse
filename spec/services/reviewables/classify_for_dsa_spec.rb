# frozen_string_literal: true

RSpec.describe Reviewables::ClassifyForDsa do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(**attributes) }

    let(:attributes) do
      {
        reviewable_id: 1,
        dsa_category: "STATEMENT_CATEGORY_CYBER_VIOLENCE",
        dsa_subcategory: "KEYWORD_CYBER_HARASSMENT",
      }
    end

    it { is_expected.to validate_presence_of(:reviewable_id) }

    it "accepts a keyword that belongs to the category" do
      expect(contract).to be_valid
    end

    it "accepts a category without a keyword" do
      attributes[:dsa_subcategory] = ""
      expect(contract).to be_valid
    end

    it "rejects an unknown category" do
      attributes[:dsa_category] = "STATEMENT_CATEGORY_MADE_UP"
      expect(contract).to be_invalid
      expect(contract.errors).to include(:dsa_category)
    end

    it "rejects a keyword from a different category" do
      attributes[:dsa_subcategory] = "KEYWORD_PHISHING"
      expect(contract).to be_invalid
      expect(contract.errors).to include(:dsa_subcategory)
    end

    it "requires a description for the other keyword" do
      attributes[:dsa_subcategory] = "KEYWORD_OTHER"
      expect(contract).to validate_presence_of(:dsa_subcategory_other)
      expect(contract).to validate_length_of(:dsa_subcategory_other).is_at_most(500)
    end

    it "discards the description when the keyword isn't other" do
      attributes[:dsa_subcategory_other] = "leftover"
      contract.validate
      expect(contract.dsa_subcategory_other).to be_nil
    end

    it "derives the legal basis from the category" do
      expect(contract.legal_basis).to eq("DECISION_GROUND_ILLEGAL_CONTENT")
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:moderator)
    fab!(:reviewable) do
      Fabricate(
        :reviewable_flagged_post,
        status: :approved,
        legal_basis: "DECISION_GROUND_ILLEGAL_CONTENT",
      )
    end

    let(:params) do
      {
        reviewable_id:,
        dsa_category: "STATEMENT_CATEGORY_CYBER_VIOLENCE",
        dsa_subcategory: "KEYWORD_OTHER",
        dsa_subcategory_other: "Doxxing",
      }
    end
    let(:dependencies) { { guardian: } }
    let(:guardian) { moderator.guardian }
    let(:reviewable_id) { reviewable.id }

    before { SiteSetting.enable_dsa_reporting = true }

    context "when contract is invalid" do
      let(:reviewable_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when DSA reporting is disabled" do
      before { SiteSetting.enable_dsa_reporting = false }

      it { is_expected.to fail_a_policy(:dsa_reporting_enabled) }
    end

    context "when the reviewable isn't visible to the user" do
      let(:guardian) { Fabricate(:user).guardian }

      it { is_expected.to fail_to_find_a_model(:reviewable) }
    end

    context "when the user can't review the target" do
      before { Reviewable.any_instance.stubs(:can_review_target?).returns(false) }

      it { is_expected.to fail_a_policy(:can_review_target) }
    end

    context "when the outcome doesn't need a classification" do
      before { reviewable.update!(legal_basis: nil) }

      it { is_expected.to fail_a_policy(:requires_dsa_classification) }
    end

    context "when the category belongs to the other legal basis" do
      before { reviewable.update!(legal_basis: "DECISION_GROUND_INCOMPATIBLE_CONTENT") }

      it { is_expected.to fail_a_policy(:category_matches_legal_basis) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "stores the classification on the reviewable" do
        result
        expect(reviewable.reload).to have_attributes(
          legal_basis: "DECISION_GROUND_ILLEGAL_CONTENT",
          dsa_category: "STATEMENT_CATEGORY_CYBER_VIOLENCE",
          dsa_subcategory: "KEYWORD_OTHER",
          dsa_subcategory_other: "Doxxing",
        )
      end

      it "takes the reviewable out of the pending queue" do
        expect { result }.to change { Reviewable.list_for(moderator).exists?(reviewable.id) }.from(
          true,
        ).to(false)
      end

      it "logs the classification to the reviewable history" do
        expect { result }.to change { reviewable.reviewable_histories.dsa_classified.count }.by(1)
        expect(reviewable.reviewable_histories.dsa_classified.last).to have_attributes(
          created_by: moderator,
          edited:
            include(
              "legal_basis" => "DECISION_GROUND_ILLEGAL_CONTENT",
              "dsa_subcategory_other" => "Doxxing",
            ),
        )
      end

      it "notifies moderators so their queues update" do
        expect_enqueued_with(
          job: :notify_reviewable,
          args: {
            reviewable_id: reviewable.id,
            performing_username: moderator.username,
            updated_reviewable_ids: [reviewable.id],
          },
        ) { result }
      end
    end
  end
end
