# frozen_string_literal: true

RSpec.describe ReviewableAiChatMessage, type: :model do
  fab!(:moderator)
  fab!(:user)
  fab!(:chat_channel)
  fab!(:chat_message) { Fabricate(:chat_message, chat_channel: chat_channel, user: user) }
  fab!(:reviewable) { described_class.needs_review!(target: chat_message, created_by: moderator) }

  before { enable_current_plugin }

  describe "#perform" do
    it "suspends the author and deletes the flagged message" do
      reviewable.update!(target_created_by: user)

      result =
        reviewable.perform(
          moderator,
          :agree_and_suspend,
          reason: "spam",
          suspend_until: 2.days.from_now,
        )

      expect(result).to be_success
      expect(user.reload).to be_suspended
      expect(chat_message.reload.deleted_at).to be_present
      expect(reviewable.reload).to be_approved
    end

    it "keeps the content and reviewable unchanged when silence details are invalid" do
      reviewable.update!(target_created_by: user)

      result = reviewable.perform(moderator, :agree_and_silence, reason: "spam")

      expect(result).not_to be_success
      expect(user.reload).not_to be_silenced
      expect(chat_message.reload.deleted_at).to be_nil
      expect(reviewable.reload).to be_pending
    end

    context "when the dsa_reporting_enabled site setting is enabled" do
      before do
        reviewable.update!(target_created_by: chat_message.user)
        freeze_time
        SiteSetting.dsa_reporting_enabled = true
      end

      it "creates no statement when agree_and_keep_message handles the AI chat message reviewable" do
        expect {
          expect(reviewable.perform(moderator, :agree_and_keep_message)).to be_success
        }.not_to change(DsaStatementOfRecord, :count)
      end

      it "records a statement when agree_and_delete handles the AI chat message reviewable" do
        expect { reviewable.perform(moderator, :agree_and_delete) }.to change(
          DsaStatementOfRecord,
          :count,
        ).by(1)

        statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)

        expect(statement).to be_pending
        expect(statement.payload).to eq(
          "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
          "decision_facts" => "The chat message was flagged by an automated system and removed.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_decision" => "AUTOMATED_DECISION_NOT_AUTOMATED",
          "content_type" => ["CONTENT_TYPE_TEXT"],
          "content_date" => chat_message.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
          "automated_detection" => "Yes",
        )
      end

      it "records a statement when delete_and_agree handles the AI chat message reviewable" do
        expect { reviewable.perform(moderator, :delete_and_agree) }.to change(
          DsaStatementOfRecord,
          :count,
        ).by(1)

        statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)

        expect(statement).to be_pending
        expect(statement.payload).to eq(
          "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
          "decision_facts" => "The chat message was flagged by an automated system and removed.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_decision" => "AUTOMATED_DECISION_NOT_AUTOMATED",
          "content_type" => ["CONTENT_TYPE_TEXT"],
          "content_date" => chat_message.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
          "automated_detection" => "Yes",
        )
      end

      it "records a statement when agree_and_keep_deleted handles the AI chat message reviewable" do
        chat_message.trash!(moderator)

        expect { reviewable.perform(moderator, :agree_and_keep_deleted) }.to change(
          DsaStatementOfRecord,
          :count,
        ).by(1)

        statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)

        expect(statement).to be_pending
        expect(statement.payload).to eq(
          "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
          "decision_facts" => "The chat message was flagged by an automated system and removed.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_decision" => "AUTOMATED_DECISION_NOT_AUTOMATED",
          "content_type" => ["CONTENT_TYPE_TEXT"],
          "content_date" => chat_message.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
          "automated_detection" => "Yes",
        )
      end

      it "creates no statement when agree_and_restore handles the AI chat message reviewable" do
        chat_message.trash!(moderator)

        expect {
          expect(reviewable.perform(moderator, :agree_and_restore)).to be_success
        }.not_to change(DsaStatementOfRecord, :count)
      end

      it "creates no statement when disagree_and_restore handles the AI chat message reviewable" do
        chat_message.trash!(moderator)

        expect {
          expect(reviewable.perform(moderator, :disagree_and_restore)).to be_success
        }.not_to change(DsaStatementOfRecord, :count)
      end

      it "creates no statement when disagree handles the AI chat message reviewable" do
        expect { expect(reviewable.perform(moderator, :disagree)).to be_success }.not_to change(
          DsaStatementOfRecord,
          :count,
        )
      end

      it "creates no statement when ignore handles the AI chat message reviewable" do
        expect { expect(reviewable.perform(moderator, :ignore)).to be_success }.not_to change(
          DsaStatementOfRecord,
          :count,
        )
      end

      it "records a statement when agree_and_suspend handles the AI chat message reviewable" do
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
          "decision_facts" =>
            "The author of a chat message flagged by an automated system was suspended.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_decision" => "AUTOMATED_DECISION_NOT_AUTOMATED",
          "content_type" => ["CONTENT_TYPE_OTHER"],
          "content_type_other" => "User account",
          "content_date" => chat_message.user.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "decision_account" => "DECISION_ACCOUNT_SUSPENDED",
          "end_date_account_restriction" => 2.days.from_now.to_date.iso8601,
          "automated_detection" => "Yes",
        )
      end

      it "records a statement when agree_and_silence handles the AI chat message reviewable" do
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
            "The author of a chat message flagged by an automated system had their ability to participate restricted.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_decision" => "AUTOMATED_DECISION_NOT_AUTOMATED",
          "content_type" => ["CONTENT_TYPE_OTHER"],
          "content_type_other" => "User account",
          "content_date" => chat_message.user.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "decision_provision" => "DECISION_PROVISION_PARTIAL_SUSPENSION",
          "end_date_service_restriction" => 2.days.from_now.to_date.iso8601,
          "automated_detection" => "Yes",
        )
      end
    end
  end

  it "agree_and_keep agrees with the flag and doesn't delete the message" do
    reviewable.perform(moderator, :agree_and_keep_message)

    expect(reviewable).to be_approved
    expect(chat_message.reload.deleted_at).not_to be_present
  end

  it "agree_and_delete agrees with the flag and deletes the message" do
    chat_message_id = chat_message.id
    reviewable.perform(moderator, :agree_and_delete)

    expect(reviewable).to be_approved
    expect(Chat::Message.with_deleted.find_by(id: chat_message_id).deleted_at).to be_present
  end

  it "agree_and_restore agrees with the flag and restores the message" do
    chat_message.trash!(user)
    reviewable.perform(moderator, :agree_and_restore)

    expect(reviewable).to be_approved
    expect(chat_message.reload.deleted_at).to be_nil
  end

  it "perform_disagree disagrees with the flag and does nothing" do
    reviewable.perform(moderator, :disagree)

    expect(reviewable).to be_rejected
  end

  it "perform_disagree_and_restore disagrees with the flag and restores the message" do
    chat_message.trash!(user)
    reviewable.perform(moderator, :disagree_and_restore)

    expect(reviewable).to be_rejected
    expect(chat_message.reload.deleted_at).to be_nil
  end

  it "perform_ignore ignores the flag and does nothing" do
    reviewable.perform(moderator, :ignore)

    expect(reviewable).to be_ignored
    expect(chat_message.reload.deleted_at).not_to be_present
  end

  context "when the flagged message author is silenced" do
    before do
      UserSilencer.silence(
        user,
        Discourse.system_user,
        silenced_till: 10.minutes.from_now,
        reason: I18n.t("chat.errors.auto_silence_from_flags"),
      )
    end

    it "perform_disagree unsilences the user" do
      reviewable.perform(moderator, :disagree)

      expect(user.reload.silenced?).to eq(false)
    end

    it "perform_disagree_and_restore unsilences the user" do
      chat_message.trash!(user)
      reviewable.perform(moderator, :disagree_and_restore)

      expect(user.reload.silenced?).to eq(false)
    end
  end
end
