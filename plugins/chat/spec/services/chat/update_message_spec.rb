# frozen_string_literal: true

RSpec.describe Chat::UpdateMessage do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(upload_ids: upload_ids) }

    let(:upload_ids) { nil }

    it { is_expected.to validate_presence_of :message_id }

    context "when uploads are not provided" do
      it { is_expected.to validate_presence_of :message }
    end

    context "when uploads are provided" do
      let(:upload_ids) { "2,3" }

      it { is_expected.not_to validate_presence_of :message }
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params) }

    fab!(:current_user) { Fabricate(:user) }
    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:upload_1) { Fabricate(:upload, user: current_user) }
    fab!(:message_1) do
      Fabricate(
        :chat_message,
        chat_channel_id: channel_1.id,
        message: "old",
        upload_ids: [upload_1.id],
        user: current_user,
      )
    end

    let(:guardian) { current_user.guardian }
    let(:message) { "new" }
    let(:message_id) { message_1.id }
    let(:upload_ids) { [upload_1.id] }
    let(:params) do
      { guardian: guardian, message_id: message_id, message: message, upload_ids: upload_ids }
    end

    before do
      SiteSetting.chat_editing_grace_period = 10
      SiteSetting.chat_editing_grace_period_max_diff_low_trust = 10
      SiteSetting.chat_editing_grace_period_max_diff_high_trust = 40
    end

    context "when all steps pass" do
      it "sets the service result as successful" do
        expect(result).to run_service_successfully
      end

      it "updates the message" do
        expect(result.message.message).to eq("new")
      end

      it "updates the uploads" do
        upload_1 = Fabricate(:upload, user: current_user)
        upload_2 = Fabricate(:upload, user: current_user)
        params[:upload_ids] = [upload_1.id, upload_2.id]

        expect(result.message.upload_ids).to contain_exactly(upload_1.id, upload_2.id)
      end

      it "keeps the existing uploads" do
        expect(result.message.upload_ids).to eq([upload_1.id])
      end

      it "does not update last editor" do
        # message can only be updated by the original author
        message_1.update!(last_editor: Discourse.system_user)

        expect { result }.to not_change { result.message.last_editor_id }
      end
    end

    context "when params are not valid" do
      before { params.delete(:message_id) }

      it { is_expected.to fail_a_contract }
    end

    context "when user can't modify a channel message" do
      before { channel_1.update!(status: :read_only) }

      it { is_expected.to fail_a_policy(:can_modify_channel_message) }
    end

    context "when user can't modify this message" do
      let(:message_id) { Fabricate(:chat_message).id }

      it { is_expected.to fail_a_policy(:can_modify_message) }
    end

    context "when edit grace period" do
      it "does not create a revision when under (n) seconds" do
        freeze_time 5.seconds.from_now
        message_1.update!(message: "hello")

        expect { result }.to not_change { Chat::MessageRevision.count }
      end

      it "does not create a revision when under (n) chars" do
        message_1.update!(message: "hi :)")

        expect { result }.to not_change { Chat::MessageRevision.count }
      end

      it "creates a revision when over (n) seconds" do
        freeze_time 30.seconds.from_now
        message_1.update!(message: "welcome")

        expect { result }.to change { Chat::MessageRevision.count }.by(1)
      end

      it "creates a revision when over (n) chars" do
        message_1.update!(message: "hey there, how are you doing today?")

        expect { result }.to change { Chat::MessageRevision.count }.by(1)
      end

      it "allows trusted users to make larger edits without creating revision" do
        current_user.update!(trust_level: TrustLevel[4])
        message_1.update!(message: "good morning, how are you doing today??")

        expect { result }.to not_change { Chat::MessageRevision.count }
      end
    end
  end
end
