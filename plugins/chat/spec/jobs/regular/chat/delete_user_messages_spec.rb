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

    it "keeps the account statement without recording deferred message cleanup" do
      SiteSetting.dsa_reporting_enabled = true
      admin = Fabricate(:admin)
      chat_message.update!(created_at: 1.day.ago)
      message_id = chat_message.id
      author_id = user_1.id
      flagged_post = Fabricate(:post, user: user_1)
      flagger = Fabricate(:user, trust_level: TrustLevel[2])
      message_reviewable =
        Fabricate(:chat_reviewable_message, target: chat_message, created_by: flagger)
      reviewable = PostActionCreator.spam(flagger, flagged_post).reviewable
      reviewable.perform(admin, :delete_user)
      statement = DsaStatementOfRecord.where(reviewable_id: reviewable.id).sole
      reviewable.destroy!

      described_class.new.execute(user_id: author_id)

      expect(DsaStatementOfRecord.where(reviewable_id: reviewable.id).sole.id).to eq(statement.id)
      expect(statement.reload.payload["decision_account"]).to eq("DECISION_ACCOUNT_TERMINATED")
      expect(statement.payload).not_to have_key("decision_visibility")
      expect(Reviewable.exists?(reviewable.id)).to eq(false)
      expect(Chat::Message.with_deleted.exists?(message_id)).to eq(false)
      expect(Reviewable.exists?(message_reviewable.id)).to eq(false)
      expect { described_class.new.execute(user_id: author_id) }.not_to change {
        DsaStatementOfRecord.count
      }
    end

    it "deletes trashed messages" do
      chat_message.trash!

      execute

      expect(Chat::Message.with_deleted.where(id: chat_message.id)).to be_empty
    end
  end
end
