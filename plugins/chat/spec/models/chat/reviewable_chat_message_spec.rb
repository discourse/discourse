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
