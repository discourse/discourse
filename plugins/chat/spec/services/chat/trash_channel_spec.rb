# frozen_string_literal: true

RSpec.describe Chat::TrashChannel do
  subject(:result) { described_class.call(params:, **dependencies) }

  fab!(:current_user) { Fabricate(:admin) }
  fab!(:channel) { Fabricate(:chat_channel) }

  let(:params) { { channel_id: } }
  let(:dependencies) { { guardian: } }
  let(:guardian) { Guardian.new(current_user) }
  let(:channel_id) { channel.id }

  context "when channel_id is not provided" do
    let(:channel_id) { nil }

    it { is_expected.to fail_to_find_a_model(:channel) }
  end

  context "when channel_id is provided" do
    context "when user is not allowed to perform the action" do
      let!(:current_user) { Fabricate(:user) }

      it { is_expected.to fail_a_policy(:invalid_access) }
    end

    context "when user is allowed to perform the action" do
      it { is_expected.to run_successfully }

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
        expect { result }.to change(Jobs::Chat::ChannelDelete.jobs, :size).by(1)
      end
    end
  end
end
