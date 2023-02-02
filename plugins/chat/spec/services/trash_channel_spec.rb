# frozen_string_literal: true

RSpec.describe(Chat::Service::TrashChannel) do
  subject(:result) { described_class.call(guardian: guardian) }

  let(:guardian) { Guardian.new(current_user) }

  context "when channel_id is not provided" do
    fab!(:current_user) { Fabricate(:admin) }

    it { is_expected.to fail_to_find_a_model(:channel) }
  end

  context "when channel_id is provided" do
    subject(:result) { described_class.call(channel_id: channel.id, guardian: guardian) }

    fab!(:channel) { Fabricate(:chat_channel) }

    context "when user is not allowed to perform the action" do
      fab!(:current_user) { Fabricate(:user) }

      it { is_expected.to fail_a_policy(:invalid_access) }
    end

    context "when user is allowed to perform the action" do
      fab!(:current_user) { Fabricate(:admin) }

      it { is_expected.to be_a_success }

      it "trashes the channel" do
        expect(result[:channel]).to be_trashed
      end

      it "logs the action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          custom_type: "chat_channel_delete",
          details:
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
end
