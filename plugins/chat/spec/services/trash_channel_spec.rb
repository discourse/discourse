# frozen_string_literal: true

RSpec.describe(Chat::Service::TrashChannel) do
  subject(:result) { described_class.call(guardian: guardian) }

  let(:guardian) { Guardian.new(current_user) }

  context "when user is not allowed to perform the action" do
    fab!(:current_user) { Fabricate(:user) }

    it { is_expected.to fail_a_policy(:invalid_access) }
  end

  context "when channel is not provided" do
    fab!(:current_user) { Fabricate(:admin) }

    it { is_expected.to fail_a_contract.with_error("Channel #{I18n.t("errors.messages.blank")}") }
  end

  context "when user is allowed to perform the action" do
    subject(:result) { described_class.call(channel: Fabricate(:chat_channel), guardian: guardian) }

    fab!(:current_user) { Fabricate(:admin) }

    it "succeeds" do
      expect(result).to succeed
    end

    it "trashes the channel" do
      expect(result[:channel]).to be_trashed
    end

    it "logs the action" do
      expect { result }.to change { UserHistory.count }.by(1)
      expect(UserHistory.last).to have_attributes custom_type: "chat_channel_delete",
                      details:
                        "chat_channel_id: #{result[:channel].id}\nchat_channel_name: #{result[:channel].title(guardian.user)}"
    end

    it "changes the slug to prevent colisions" do
      expect(result[:channel].slug).to include("deleted")
    end

    it "queues a job to delete channel relations" do
      expect { result }.to change(Jobs::ChatChannelDelete.jobs, :size).by(1)
    end
  end
end
