# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReviewableLiveUser do
  fab!(:moderator)
  fab!(:flagger, :user)
  fab!(:flagged_user, :user)
  fab!(:room, :live_room)
  fab!(:session) { Fabricate(:live_session, room: room, user: flagged_user) }

  fab!(:reviewable) do
    reviewable =
      ReviewableLiveUser.needs_review!(
        created_by: flagger,
        target: session,
        reviewable_by_moderator: true,
      )
    reviewable.update!(
      target_created_by: flagged_user,
      payload: {
        message: "Being disruptive",
        room_id: room.id,
        room_name: room.name,
        room_slug: room.slug,
      },
    )
    reviewable.add_score(flagger, ReviewableScore.types[:notify_moderators])
    reviewable
  end

  before { SiteSetting.live_enabled = true }

  describe "#build_actions" do
    it "offers agree, suspend/silence, disagree and ignore to a moderator" do
      actions = reviewable.actions_for(moderator.guardian)

      expect(actions.to_a.map(&:server_action).map(&:to_sym)).to contain_exactly(
        :agree_and_keep,
        :agree_and_suspend,
        :agree_and_silence,
        :disagree,
        :ignore,
      )
    end

    it "offers no actions once the reviewable is handled" do
      reviewable.perform(moderator, :ignore)

      expect(reviewable.actions_for(moderator.guardian).to_a).to be_empty
    end
  end

  describe "#perform" do
    it "suspends the user and agrees with the flag" do
      result =
        reviewable.perform(
          moderator,
          :agree_and_suspend,
          reason: "Disruptive behavior",
          suspend_until: 2.days.from_now,
        )

      expect(result).to be_success
      expect(flagged_user.reload).to be_suspended
      expect(reviewable.reload).to be_approved
      expect(reviewable.reviewable_scores.first).to be_agreed
    end

    it "silences the user and agrees with the flag" do
      result =
        reviewable.perform(
          moderator,
          :agree_and_silence,
          reason: "Disruptive behavior",
          silenced_till: 2.days.from_now,
        )

      expect(result).to be_success
      expect(flagged_user.reload).to be_silenced
      expect(reviewable.reload).to be_approved
      expect(reviewable.reviewable_scores.first).to be_agreed
    end

    it "leaves the user and flag unchanged when suspension details are invalid" do
      result = reviewable.perform(moderator, :agree_and_suspend, reason: "Disruption")

      expect(result).not_to be_success
      expect(flagged_user.reload).not_to be_suspended
      expect(reviewable.reload).to be_pending
      expect(reviewable.reviewable_scores.first).to be_pending
    end

    it "approves the reviewable and agrees with the flag on agree_and_keep" do
      reviewable.perform(moderator, :agree_and_keep)

      expect(reviewable.reload).to be_approved
      expect(reviewable.reviewable_scores.first).to be_agreed
    end

    it "rejects the reviewable and disagrees with the flag on disagree" do
      reviewable.perform(moderator, :disagree)

      expect(reviewable.reload).to be_rejected
      expect(reviewable.reviewable_scores.first).to be_disagreed
    end

    it "ignores the reviewable and the flag on ignore" do
      reviewable.perform(moderator, :ignore)

      expect(reviewable.reload).to be_ignored
      expect(reviewable.reviewable_scores.first).to be_ignored
    end

    context "when the dsa_reporting_enabled site setting is enabled" do
      before do
        freeze_time
        SiteSetting.dsa_reporting_enabled = true
      end

      it "creates no statement when agree_and_keep handles the live user reviewable" do
        expect {
          expect(reviewable.perform(moderator, :agree_and_keep)).to be_success
        }.not_to change(DsaStatementOfRecord, :count)
      end

      it "creates no statement when disagree handles the live user reviewable" do
        expect { expect(reviewable.perform(moderator, :disagree)).to be_success }.not_to change(
          DsaStatementOfRecord,
          :count,
        )
      end

      it "creates no statement when ignore handles the live user reviewable" do
        expect { expect(reviewable.perform(moderator, :ignore)).to be_success }.not_to change(
          DsaStatementOfRecord,
          :count,
        )
      end

      it "records a statement when agree_and_suspend handles the live user reviewable" do
        expect {
          reviewable.perform(
            moderator,
            :agree_and_suspend,
            reason: "Spam",
            suspend_until: 2.days.from_now,
          )
        }.to change(DsaStatementOfRecord, :count).by(1)

        statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)

        expect(statement).to be_pending
        expect(statement.payload).to eq(
          "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
          "decision_facts" => "The user reported during a live call was suspended.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_detection" => "No",
          "automated_decision" => "AUTOMATED_DECISION_NOT_AUTOMATED",
          "content_type" => ["CONTENT_TYPE_OTHER"],
          "content_date" => flagged_user.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "content_type_other" => "User account",
          "decision_account" => "DECISION_ACCOUNT_SUSPENDED",
          "end_date_account_restriction" => 2.days.from_now.to_date.iso8601,
        )
      end

      it "records a statement when agree_and_silence handles the live user reviewable" do
        expect {
          reviewable.perform(
            moderator,
            :agree_and_silence,
            reason: "Spam",
            silenced_till: 2.days.from_now,
          )
        }.to change(DsaStatementOfRecord, :count).by(1)

        statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)

        expect(statement).to be_pending
        expect(statement.payload).to eq(
          "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
          "decision_facts" =>
            "The user reported during a live call had their ability to participate restricted.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_detection" => "No",
          "automated_decision" => "AUTOMATED_DECISION_NOT_AUTOMATED",
          "content_type" => ["CONTENT_TYPE_OTHER"],
          "content_date" => flagged_user.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "content_type_other" => "User account",
          "decision_provision" => "DECISION_PROVISION_PARTIAL_SUSPENSION",
          "end_date_service_restriction" => 2.days.from_now.to_date.iso8601,
        )
      end
    end
  end
end
