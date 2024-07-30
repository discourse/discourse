# frozen_string_literal: true

RSpec.describe Chat::FlagMessage do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new }

    it { is_expected.to validate_presence_of(:channel_id) }
    it { is_expected.to validate_presence_of(:message_id) }

    it do
      is_expected.to validate_inclusion_of(:flag_type_id).in_array(ReviewableScore.types.values)
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params) }

    fab!(:current_user) { Fabricate(:user) }
    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

    let(:guardian) { Guardian.new(current_user) }
    let(:channel_id) { channel_1.id }
    let(:message_id) { message_1.id }
    let(:flag_type_id) { ReviewableScore.types[:off_topic] }
    let(:message) { nil }
    let(:is_warning) { nil }
    let(:take_action) { nil }

    before { SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:everyone] }

    let(:params) do
      {
        guardian: guardian,
        channel_id: channel_id,
        message_id:,
        flag_type_id: flag_type_id,
        message: message,
        is_warning: is_warning,
        take_action: take_action,
      }
    end

    context "when all steps pass" do
      fab!(:current_user) { Fabricate(:admin) }

      it "flags the message" do
        expect { result }.to change { Reviewable.count }.by(1)

        reviewable = Reviewable.last
        expect(reviewable.target_type).to eq("ChatMessage")
        expect(reviewable.created_by_id).to eq(current_user.id)
        expect(reviewable.target_created_by_id).to eq(message_1.user.id)
        expect(reviewable.target_id).to eq(message_1.id)
        expect(reviewable.payload).to eq("message_cooked" => message_1.cooked)
      end
    end

    context "when channel is not found" do
      before { params[:channel_id] = -999 }

      it { is_expected.to fail_to_find_a_model(:message) }
    end

    context "when user is silenced" do
      before { UserSilencer.new(current_user).silence }

      it { is_expected.to fail_a_policy(:can_flag_message_in_channel) }
    end

    context "when channel is in read only mode" do
      before { channel_1.update!(status: Chat::Channel.statuses[:read_only]) }

      it { is_expected.to fail_a_policy(:can_flag_message_in_channel) }
    end

    context "when flagging staff message is not allowed" do
      before { SiteSetting.allow_flagging_staff = false }

      fab!(:message_1) do
        Fabricate(:chat_message, chat_channel: channel_1, user: Fabricate(:admin))
      end

      it { is_expected.to fail_a_policy(:can_flag_message_in_channel) }
    end

    context "when flagging its own message" do
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, user: current_user) }

      before { UserSilencer.new(current_user).silence }

      it { is_expected.to fail_a_policy(:can_flag_message_in_channel) }
    end

    context "when message is not found" do
      before { params[:message_id] = -999 }

      it { is_expected.to fail_to_find_a_model(:message) }
    end

    context "when user doesn't have access to channel" do
      fab!(:channel_1) { Fabricate(:private_category_channel, group: Fabricate(:group)) }
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

      it { is_expected.to fail_a_policy(:can_flag_message_in_channel) }
    end
  end
end
