# frozen_string_literal: true

RSpec.describe Jobs::Chat::DeleteUserMessages do
  describe "#execute" do
    subject(:execute) { described_class.new.execute(user_id: user_1) }

    fab!(:user_1, :user)
    fab!(:channel, :chat_channel)
    fab!(:chat_message) { Fabricate(:chat_message, chat_channel: channel, user: user_1) }

    it "deletes messages from the user" do
      execute

      expect { chat_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "doesn't delete messages from other users" do
      user_2 = Fabricate(:user)
      user_2_message = Fabricate(:chat_message, chat_channel: channel, user: user_2)

      execute

      expect(user_2_message.reload).to be_present
    end

    it "retains classified review queue reporting for deferred account deletion" do
      SiteSetting.dsa_reporting_enabled = true
      admin = Fabricate(:admin)
      message_id = chat_message.id
      author_id = user_1.id
      flagged_post = Fabricate(:post, user: user_1)
      flagger = Fabricate(:user, trust_level: TrustLevel[2])
      reviewable = PostActionCreator.spam(flagger, flagged_post).reviewable
      reviewable.perform(admin, :delete_user)
      statement = DsaStatementOfReason.find_by!(reviewable_id: reviewable.id, target_type: "User")
      DsaStatementOfReason::Classify.call(
        guardian: admin.guardian,
        params: {
          reviewable_id: reviewable.id,
          decision_key: statement.decision_key,
          community_rule: "spam",
          category: "STATEMENT_CATEGORY_OTHER_VIOLATION_TC",
        },
      )

      described_class.new.execute(user_id: author_id, dsa_decision_key: statement.decision_key)

      removed_message =
        DsaStatementOfReason.find_by!(
          reviewable_id: reviewable.id,
          target_type: "Chat::Message",
          target_id: message_id,
        )
      expect(removed_message.payload).to include(
        "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
        "source_type" => "SOURCE_TYPE_OTHER_NOTIFICATION",
        "category" => "STATEMENT_CATEGORY_OTHER_VIOLATION_TC",
      )
      expect(removed_message.classified_at).to be_present
      expect(removed_message.decision_key).to eq(statement.decision_key)
      expect(Reviewable.exists?(reviewable.id)).to eq(true)
      expect(Chat::Message.with_deleted.exists?(message_id)).to eq(false)
    end

    it "deletes trashed messages" do
      chat_message.trash!

      execute

      expect(Chat::Message.with_deleted.where(id: chat_message.id)).to be_empty
    end
  end
end
