# frozen_string_literal: true

RSpec.describe Chat::FlagMessage do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:channel_id) }
    it { is_expected.to validate_presence_of(:message_id) }

    it do
      is_expected.to validate_inclusion_of(:flag_type_id).in_array(ReviewableScore.types.values)
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user, :user)
    fab!(:channel_1, :chat_channel)
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

    let(:guardian) { Guardian.new(current_user) }
    let(:channel_id) { channel_1.id }
    let(:message_id) { message_1.id }
    let(:flag_type_id) { ReviewableScore.types[:off_topic] }
    let(:message) { nil }
    let(:is_warning) { nil }
    let(:take_action) { nil }
    let(:params) do
      {
        channel_id: channel_id,
        message_id:,
        flag_type_id: flag_type_id,
        message: message,
        is_warning: is_warning,
        take_action: take_action,
      }
    end
    let(:dependencies) { { guardian: } }

    before do
      SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:everyone]
      SiteSetting.chat_enabled = true
      SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
      SiteSetting.chat_message_flag_allowed_groups = Group::AUTO_GROUPS[:everyone]
    end

    context "when all steps pass" do
      fab!(:current_user, :admin)

      let(:reviewable) { Reviewable.last }

      it { is_expected.to run_successfully }

      it "flags the message" do
        expect { result }.to change { Reviewable.count }.by(1)
        expect(reviewable).to have_attributes(
          target: message_1,
          created_by: current_user,
          target_created_by: message_1.user,
          payload: {
            "message_cooked" => message_1.cooked,
          },
        )
      end
    end

    context "when the review queue rejects the flag" do
      before do
        Chat::ReviewQueue.new.flag_message(message_1, guardian, ReviewableScore.types[:spam])
      end

      it "fails and retains the duplicate flag error" do
        expect(result).to fail_a_step(:flag_message)
        expect(result.failure?).to eq(true)
        expect(result["result.step.flag_message"].error).to eq(
          [I18n.t("chat.reviewables.message_already_handled")],
        )
      end
    end

    context "when the notify user companion PM cannot be created" do
      let(:flag_type_id) { ReviewableScore.types[:notify_user] }
      let(:message) { "Please review your chat message" }

      before { message_1.user.user_option.update!(allow_private_messages: false) }

      it "fails and retains the PostCreator error" do
        expect(result).to fail_a_step(:flag_message)
        expect(result.failure?).to eq(true)
        expect(result["result.step.flag_message"].error).to eq(
          [I18n.t("not_accepting_pms", username: message_1.user.username)],
        )
      end
    end

    context "when contract is invalid" do
      let(:channel_id) { nil }

      it { is_expected.to fail_a_contract }
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
