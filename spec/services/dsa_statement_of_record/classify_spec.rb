# frozen_string_literal: true

RSpec.describe DsaStatementOfRecord::Classify do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)
    fab!(:reviewable, :reviewable_flagged_post)
    fab!(:statement) { Fabricate(:dsa_statement_of_record, reviewable_id: reviewable.id) }

    let(:dependencies) { { guardian: acting_user.guardian } }
    let(:rule) do
      {
        "ground" => "Terms of Service, section 3: Personal attacks",
        "explanation" => "The content targets another person with insults.",
      }
    end
    let(:params) do
      {
        reviewable_id: reviewable.id,
        community_rule: DsaStatementOfRecord.community_rules.first.fetch("id"),
        category: "STATEMENT_CATEGORY_ILLEGAL_OR_HARMFUL_SPEECH",
        statement_ids: [statement.id],
      }
    end

    before do
      SiteSetting.dsa_reporting_enabled = true
      SiteSetting.dsa_community_rules = [rule].to_json
    end

    it "classifies a flagged post removal and records the staff member's decision in a note" do
      original_payload = statement.payload
      freeze_time

      expect { result }.to change { reviewable.reviewable_notes.count }.by(1)

      expect(result).to run_successfully
      expect(statement.reload).to have_attributes(
        status: "ready",
        classified_by_id: acting_user.id,
        classified_at: eq_time(Time.current),
        payload:
          original_payload.merge(
            "incompatible_content_ground" => rule["ground"],
            "incompatible_content_explanation" => rule["explanation"],
            "category" => "STATEMENT_CATEGORY_ILLEGAL_OR_HARMFUL_SPEECH",
          ),
      )
      expect(reviewable.reviewable_notes.last).to have_attributes(
        user: acting_user,
        content: <<~TEXT.chomp,
          Classified this moderation decision for DSA reporting.
          Community rule: Terms of Service, section 3: Personal attacks
          Category: Illegal or harmful speech
        TEXT
      )
    end

    it "classifies a flagged post removal and account suspension with one moderation note" do
      account_statement =
        Fabricate(
          :dsa_statement_of_record,
          reviewable_id: reviewable.id,
          payload: {
            "decision_account" => "DECISION_ACCOUNT_SUSPENDED",
            "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
            "decision_facts" => "The reviewed account was suspended.",
          },
        )
      params[:statement_ids] << account_statement.id

      expect { result }.to change { reviewable.reviewable_notes.count }.by(1)

      expect(result).to run_successfully
      expect(statement.reload).to be_ready
      expect(account_statement.reload).to be_ready
      expect(account_statement.payload).to include(
        "incompatible_content_ground" => rule["ground"],
        "category" => params[:category],
        "decision_facts" => "The reviewed account was suspended.",
      )
    end

    it "leaves an existing classification unchanged when classifying a pending statement" do
      prior_payload = statement.payload.merge("incompatible_content_ground" => "Previous terms")
      earlier =
        Fabricate(
          :dsa_statement_of_record,
          reviewable_id: reviewable.id,
          status: :ready,
          payload: prior_payload,
        )

      expect(result).to run_successfully
      expect(statement.reload).to be_ready
      expect(earlier.reload.payload).to eq(prior_payload)
    end

    context "when the classification note is invalid" do
      before do
        TranslationOverride.upsert!(
          "en",
          "dsa_statements.classification_note",
          "x" * (ReviewableNote::MAX_CONTENT_LENGTH + 1),
        )
      end

      it "rolls back the classification without adding a note" do
        original_payload = statement.payload

        expect { result }.not_to change { reviewable.reviewable_notes.count }

        expect(result).to fail_with_an_invalid_model(:reviewable_note)
        expect(statement.reload).to have_attributes(
          status: "pending",
          payload: original_payload,
          classified_by_id: nil,
          classified_at: nil,
        )
      end
    end

    context "when the actor is not staff" do
      fab!(:acting_user, :user)

      it { is_expected.to fail_a_policy(:staff) }
    end

    context "when the flagged post is outside the moderator's visible categories" do
      fab!(:acting_user, :moderator)

      before { reviewable.update!(category: Fabricate(:private_category, group: Group[:admins])) }

      it "rejects classification without changing the statement or adding a note" do
        original_payload = statement.payload

        expect { result }.not_to change { reviewable.reviewable_notes.count }

        expect(result).to fail_to_find_a_model(:reviewable)
        expect(statement.reload).to be_pending
        expect(statement.payload).to eq(original_payload)
      end
    end

    context "when dsa_reporting_enabled is disabled" do
      before { SiteSetting.dsa_reporting_enabled = false }

      it { is_expected.to fail_a_policy(:classification_enabled) }
    end

    context "when community rules are empty" do
      before do
        params
        SiteSetting.dsa_community_rules = "[]"
      end

      it { is_expected.to fail_a_policy(:classification_enabled) }
    end

    context "when the category is invalid" do
      before { params[:category] = "anything" }

      it { is_expected.to fail_a_contract }
    end

    context "when the selected rule has changed" do
      before do
        params
        SiteSetting.dsa_community_rules = [
          rule.merge("explanation" => "Updated explanation"),
        ].to_json
      end

      it { is_expected.to fail_to_find_a_model(:community_rule) }
    end

    context "when no pending statements remain" do
      before { statement.update!(status: :ready) }

      it "preserves the saved classification without adding another note" do
        original_payload = statement.payload

        expect { result }.not_to change { reviewable.reviewable_notes.count }

        expect(result).to fail_to_find_a_model(:statements)
        expect(statement.reload.payload).to eq(original_payload)
      end
    end

    context "when another decision adds a statement after the form opened" do
      before { Fabricate(:dsa_statement_of_record, reviewable_id: reviewable.id) }

      it { is_expected.to fail_a_policy(:current_statements) }
    end
  end
end
