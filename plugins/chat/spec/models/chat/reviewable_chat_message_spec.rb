# frozen_string_literal: true

RSpec.describe Chat::ReviewableMessage, type: :model do
  fab!(:moderator)
  fab!(:user)
  fab!(:chat_channel)
  fab!(:chat_message) { Fabricate(:chat_message, chat_channel: chat_channel, user: user) }
  fab!(:reviewable) do
    Fabricate(:chat_reviewable_message, target: chat_message, created_by: moderator)
  end

  it { is_expected.to validate_length_of(:type).is_at_most(100) }
  it { is_expected.to validate_length_of(:target_type).is_at_most(100) }

  it "uses the channel title in reviewable note mention notifications" do
    SiteSetting.enable_mentions = true
    recipient = Fabricate(:admin)
    chat_channel.update!(name: "Reviewable mention testing")

    ReviewableNote.create!(
      reviewable: reviewable,
      user: moderator,
      content: "@#{recipient.username}",
    )

    notification =
      recipient.notifications.find_by!(notification_type: Notification.types[:mentioned])
    expect(notification.data_hash["topic_title"]).to eq(chat_channel.name)
    expect(notification.url).to eq("/review/#{reviewable.id}")
  end

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

      it "creates no statement when unsilence_user handles the chat message reviewable" do
        UserSilencer.silence(user, moderator, silenced_till: 2.days.from_now, reason: "Spam")

        expect {
          expect(reviewable.perform(moderator, :unsilence_user)).to be_success
        }.not_to change(DsaStatementOfRecord, :count)
      end

      it "creates no statement when agree_and_keep_message handles the chat message reviewable" do
        expect {
          expect(reviewable.perform(moderator, :agree_and_keep_message)).to be_success
        }.not_to change(DsaStatementOfRecord, :count)
      end

      it "records a statement when agree_and_delete handles the chat message reviewable" do
        expect { reviewable.perform(moderator, :agree_and_delete) }.to change(
          DsaStatementOfRecord,
          :count,
        ).by(1)

        statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)

        expect(statement).to be_pending
        expect(statement.payload).to eq(
          "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
          "decision_facts" => "The flagged chat message was removed.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_detection" => "No",
          "automated_decision" => "AUTOMATED_DECISION_NOT_AUTOMATED",
          "content_type" => ["CONTENT_TYPE_TEXT"],
          "content_date" => chat_message.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
        )
      end

      it "records a statement when delete_and_agree handles the chat message reviewable" do
        expect { reviewable.perform(moderator, :delete_and_agree) }.to change(
          DsaStatementOfRecord,
          :count,
        ).by(1)

        statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)

        expect(statement).to be_pending
        expect(statement.payload).to eq(
          "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
          "decision_facts" => "The flagged chat message was removed.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_detection" => "No",
          "automated_decision" => "AUTOMATED_DECISION_NOT_AUTOMATED",
          "content_type" => ["CONTENT_TYPE_TEXT"],
          "content_date" => chat_message.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
        )
      end

      it "records a statement when agree_and_keep_deleted handles the chat message reviewable" do
        chat_message.trash!(moderator)

        expect { reviewable.perform(moderator, :agree_and_keep_deleted) }.to change(
          DsaStatementOfRecord,
          :count,
        ).by(1)

        statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)

        expect(statement).to be_pending
        expect(statement.payload).to eq(
          "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
          "decision_facts" => "The flagged chat message was removed.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_detection" => "No",
          "automated_decision" => "AUTOMATED_DECISION_NOT_AUTOMATED",
          "content_type" => ["CONTENT_TYPE_TEXT"],
          "content_date" => chat_message.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
        )
      end

      it "creates no statement when agree_and_restore handles the chat message reviewable" do
        chat_message.trash!(moderator)

        expect {
          expect(reviewable.perform(moderator, :agree_and_restore)).to be_success
        }.not_to change(DsaStatementOfRecord, :count)
      end

      it "creates no statement when disagree_and_restore handles the chat message reviewable" do
        chat_message.trash!(moderator)

        expect {
          expect(reviewable.perform(moderator, :disagree_and_restore)).to be_success
        }.not_to change(DsaStatementOfRecord, :count)
      end

      it "creates no statement when disagree handles the chat message reviewable" do
        expect { expect(reviewable.perform(moderator, :disagree)).to be_success }.not_to change(
          DsaStatementOfRecord,
          :count,
        )
      end

      it "creates no statement when ignore handles the chat message reviewable" do
        expect { expect(reviewable.perform(moderator, :ignore)).to be_success }.not_to change(
          DsaStatementOfRecord,
          :count,
        )
      end

      it "records a statement when agree_and_suspend handles the chat message reviewable" do
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
          "decision_facts" => "The author of the flagged chat message was suspended.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_detection" => "No",
          "automated_decision" => "AUTOMATED_DECISION_NOT_AUTOMATED",
          "content_type" => ["CONTENT_TYPE_OTHER"],
          "content_type_other" => "User account",
          "content_date" => chat_message.user.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "decision_account" => "DECISION_ACCOUNT_SUSPENDED",
          "end_date_account_restriction" => 2.days.from_now.to_date.iso8601,
        )
      end

      it "records a statement when agree_and_silence handles the chat message reviewable" do
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
            "The author of the flagged chat message had their ability to participate restricted.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_detection" => "No",
          "automated_decision" => "AUTOMATED_DECISION_NOT_AUTOMATED",
          "content_type" => ["CONTENT_TYPE_OTHER"],
          "content_type_other" => "User account",
          "content_date" => chat_message.user.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "decision_provision" => "DECISION_PROVISION_PARTIAL_SUSPENSION",
          "end_date_service_restriction" => 2.days.from_now.to_date.iso8601,
        )
      end
    end
  end

  it "agree_and_keep agrees with the flag and doesn't delete the message" do
    reviewable.perform(moderator, :agree_and_keep_message)

    expect(reviewable).to be_approved
    expect(chat_message.reload.deleted_at).not_to be_present
  end

  it "agree_and_keep_deleted agrees with the flag and keeps the message deleted" do
    chat_message.trash!(user)
    reviewable.perform(moderator, :agree_and_keep_deleted)
    expect(reviewable).to be_approved
    expect(chat_message.reload.deleted_at).to be_present
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

  context "when the flagged message author was silenced for this message" do
    before do
      UserSilencer.silence(
        user,
        Discourse.system_user,
        silenced_till: 10.minutes.from_now,
        reason: I18n.t("chat.errors.auto_silence_from_flags"),
        reviewable_id: reviewable.id,
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

    it "attributes the unsilence to the moderator and the reviewable" do
      reviewable.perform(moderator, :disagree)

      history =
        UserHistory.find_by(action: UserHistory.actions[:unsilence_user], target_user_id: user.id)

      expect(history.acting_user_id).to eq(moderator.id)
      expect(history.reviewable_id).to eq(reviewable.id)
    end
  end

  context "when the flagged message author was silenced for something else" do
    before do
      UserSilencer.silence(
        user,
        Discourse.system_user,
        silenced_till: 10.minutes.from_now,
        reason: "unrelated reason",
      )
    end

    it "perform_disagree leaves the user silenced" do
      reviewable.perform(moderator, :disagree)

      expect(user.reload.silenced?).to eq(true)
    end
  end

  context "when a silence from this flag was already lifted and a new one replaced it" do
    before do
      UserSilencer.silence(
        user,
        Discourse.system_user,
        silenced_till: 10.minutes.from_now,
        reason: I18n.t("chat.errors.auto_silence_from_flags"),
        reviewable_id: reviewable.id,
      )
      UserSilencer.unsilence(user, moderator)

      UserSilencer.silence(
        user,
        Discourse.system_user,
        silenced_till: 10.minutes.from_now,
        reason: "unrelated reason",
      )
    end

    it "perform_disagree leaves the later, unrelated silence in place" do
      reviewable.perform(moderator, :disagree)

      expect(user.reload.silenced?).to eq(true)
    end
  end

  describe "#perform_unsilence_user" do
    def unsilence_action(guardian = moderator.guardian)
      reviewable.actions_for(guardian).to_a.find { |a| a.server_action == "unsilence_user" }
    end

    it "is not offered when the author is not silenced" do
      expect(unsilence_action).to eq(nil)
    end

    context "when the author is silenced" do
      before do
        UserSilencer.silence(
          user,
          Discourse.system_user,
          silenced_till: 10.minutes.from_now,
          reason: I18n.t("chat.errors.auto_silence_from_flags"),
        )
      end

      it "is offered with a translated label" do
        action = unsilence_action

        expect(action).to be_present
        expect(I18n.t(action.label)).to eq("Unsilence author")
        expect(I18n.t(action.completed_message)).to eq("Author unsilenced.")
      end

      it "is set apart from the actions that resolve the flag" do
        secondary_bundles = reviewable.actions_for(moderator.guardian).bundles.select(&:secondary)

        expect(secondary_bundles.flat_map(&:actions).map(&:server_action)).to eq(["unsilence_user"])
      end

      it "is not offered to a user who cannot unsilence the author" do
        expect(unsilence_action(Fabricate(:user).guardian)).to eq(nil)
      end

      it "lifts the silence without resolving the flag" do
        reviewable.perform(moderator, :unsilence_user)

        expect(user.reload.silenced?).to eq(false)
        expect(reviewable.reload).to be_pending
      end

      it "attributes the unsilence to the moderator and the reviewable" do
        reviewable.perform(moderator, :unsilence_user)

        history =
          UserHistory.find_by(action: UserHistory.actions[:unsilence_user], target_user_id: user.id)

        expect(history.acting_user_id).to eq(moderator.id)
        expect(history.reviewable_id).to eq(reviewable.id)
      end
    end
  end
end
