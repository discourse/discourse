# frozen_string_literal: true

describe Chat::AutoJoinChannelBatch do
  describe Chat::AutoJoinChannelBatch::Contract, type: :model do
    subject(:contract) { described_class.new(start_user_id: 10) }

    it { is_expected.to validate_presence_of(:channel_id) }
    it { is_expected.to validate_presence_of(:start_user_id) }
    it { is_expected.to validate_presence_of(:end_user_id) }
    it do
      is_expected.to validate_comparison_of(:end_user_id).is_greater_than_or_equal_to(
        :start_user_id,
      )
    end

    describe "Backward compatibility" do
      subject(:contract) { described_class.new(args) }

      before { contract.valid? }

      context "when providing 'chat_channel_id'" do
        let(:args) { { chat_channel_id: 2 } }

        it "sets 'channel_id'" do
          expect(contract.channel_id).to eq(2)
        end
      end

      context "when providing 'starts_at'" do
        let(:args) { { starts_at: 5 } }

        it "sets 'start_user_id'" do
          expect(contract.start_user_id).to eq(5)
        end
      end

      context "when providing 'ends_at'" do
        let(:args) { { ends_at: 8 } }

        it "sets 'end_user_id'" do
          expect(contract.end_user_id).to eq(8)
        end
      end
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:channel) { Fabricate(:chat_channel, auto_join_users: true) }

    let(:channel_id) { channel.id }
    let(:user_ids) { [Fabricate(:user).id] }
    let(:start_user_id) { user_ids.first }
    let(:end_user_id) { user_ids.last }
    let(:params) do
      { channel_id: channel_id, start_user_id: start_user_id, end_user_id: end_user_id }
    end

    context "when arguments are invalid" do
      let(:channel_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when arguments are valid" do
      context "when channel does not exist" do
        let(:channel_id) { -1 }

        it { is_expected.to fail_to_find_a_model(:channel) }
      end

      context "when channel is not a category channel" do
        fab!(:channel) { Fabricate(:direct_message_channel, auto_join_users: true) }

        it { is_expected.to fail_to_find_a_model(:channel) }
      end

      context "when channel is not in auto_join_users mode" do
        before { channel.update!(auto_join_users: false) }

        it { is_expected.to fail_to_find_a_model(:channel) }
      end

      context "when channel is found" do
        context "when more than one membership is created" do
          let(:user_ids) { Fabricate.times(2, :user).map(&:id) }

          it { is_expected.to run_successfully }

          it "does not recalculate user count" do
            ::Chat::ChannelMembershipManager.any_instance.expects(:recalculate_user_count).never
            result
          end

          it "publishes an event for each user" do
            messages =
              MessageBus.track_publish(::Chat::Publisher::NEW_CHANNEL_MESSAGE_BUS_CHANNEL) do
                result
              end
            expect(messages.length).to eq(2)
          end
        end

        context "when only one membership is created" do
          it { is_expected.to run_successfully }

          it "recalculates user count" do
            ::Chat::ChannelMembershipManager.any_instance.expects(:recalculate_user_count).once
            result
          end

          it "publishes an event" do
            messages =
              MessageBus.track_publish(::Chat::Publisher::NEW_CHANNEL_MESSAGE_BUS_CHANNEL) do
                result
              end
            expect(messages.length).to eq(1)
          end
        end
      end
    end
  end
end
