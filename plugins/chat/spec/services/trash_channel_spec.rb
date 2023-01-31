# frozen_string_literal: true

RSpec.describe(Chat::Service::TrashChannel) do
  let(:guardian) { Guardian.new(current_user) }

  context "when user is not allowed to perform the action" do
    fab!(:current_user) { Fabricate(:user) }

    subject(:result) { described_class.call(guardian: guardian) }

    it "fails" do
      expect(result).to be_a_failure
      expect(result[:"result.policy.invalid_access"]).to be_a_failure
    end
  end

  context "when channel is not provided" do
    fab!(:current_user) { Fabricate(:admin) }

    subject(:result) { described_class.call(guardian: guardian) }

    it "fails" do
      expect(result).to fail_contract_with_error("Channel " + I18n.t("errors.messages.blank"))
    end
  end

  context "when user is allowed to perform the action" do
    fab!(:current_user) { Fabricate(:admin) }

    subject(:result) { described_class.call(channel: Fabricate(:chat_channel), guardian: guardian) }

    it "succeeds" do
      expect(result).to succeed
    end

    it "trashes the channel" do
      expect(result[:channel].trashed?).to eq(true)
    end

    it "logs the action" do
      expect { result }.to change { UserHistory.count }.by(1)

      user_history = UserHistory.last
      expect(user_history.custom_type).to eq ("chat_channel_delete")
      expect(user_history.details).to eq(
        "chat_channel_id: #{result[:channel].id}\nchat_channel_name: #{result[:channel].title(guardian.user)}",
      )
    end

    it "changes the slug to prevent colisions" do
      expect(result[:channel].slug).to include("deleted")
    end

    it "queues a job to delete channel relations" do
      expect { result }.to change(Jobs::ChatChannelDelete.jobs, :size).by(1)
    end
  end
end
