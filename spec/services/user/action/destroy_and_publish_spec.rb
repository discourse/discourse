# frozen_string_literal: true

RSpec.describe User::Action::DestroyAndPublish do
  describe ".call" do
    subject(:action) do
      described_class.call(user:, position:, guardian:, total_size:, block_ip_and_email:)
    end

    fab!(:admin)
    fab!(:user)

    let(:guardian) { admin.guardian }
    let(:position) { 2 }
    let(:total_size) { 10 }
    let(:block_ip_and_email) { true }

    before { allow(MessageBus).to receive(:publish) }

    context "when user destroyer succeeds" do
      it "publishes the result" do
        action
        expect(MessageBus).to have_received(:publish).with(
          "/bulk-user-delete",
          { position:, total: total_size, username: user.username, success: true },
          user_ids: [admin.id],
        )
      end
    end

    context "when user destroyer fails" do
      before do
        allow(user).to receive(:destroy).and_return(false)
        user.errors.add(:base, "error")
      end

      it "publishes the result" do
        action
        expect(MessageBus).to have_received(:publish).with(
          "/bulk-user-delete",
          { position:, total: total_size, username: user.username, failed: true, error: "error" },
          user_ids: [admin.id],
        )
      end
    end

    context "when user destroyer raises an error" do
      fab!(:user) { Fabricate(:admin) }

      it "publishes the result" do
        action
        expect(MessageBus).to have_received(:publish).with(
          "/bulk-user-delete",
          {
            position:,
            total: total_size,
            username: user.username,
            failed: true,
            error: "can_delete_user? failed",
          },
          user_ids: [admin.id],
        )
      end
    end
  end
end
