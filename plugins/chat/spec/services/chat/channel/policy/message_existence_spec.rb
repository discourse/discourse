# frozen_string_literal: true

RSpec.describe Chat::Channel::Policy::MessageExistence do
  subject(:policy) { described_class.new(context) }

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:channel) { Fabricate(:chat_channel) }

  let(:guardian) { user.guardian }
  let(:context) { Service::Base::Context.build(channel:, guardian:, target_message_id:) }

  describe "#call" do
    subject(:result) { policy.call }

    context "when 'target_message_id' is not provided" do
      let(:target_message_id) { nil }

      it { is_expected.to be true }
    end

    context "when 'target_message_id' is provided" do
      context "when target message does not exist" do
        let(:target_message_id) { -1 }

        it { is_expected.to be false }
      end

      context "when target message exists" do
        fab!(:message) { Fabricate(:chat_message, chat_channel: channel, user:) }

        let(:target_message_id) { message.id }

        context "when target message is not trashed" do
          it { is_expected.to be true }
        end

        context "when target message is trashed" do
          before { message.trash! }

          context "when target message’s user is the same as the guardian" do
            it { is_expected.to be true }

            it "does not set 'target_message_id' to nil" do
              expect { result }.not_to change { context.target_message_id }
            end
          end

          context "when target message’s user is different than the guardian" do
            fab!(:other_user) { Fabricate(:user, refresh_auto_groups: true) }

            before { message.update!(user: other_user) }

            context "when guardian is staff" do
              let(:guardian) { Discourse.system_user.guardian }

              it { is_expected.to be true }

              it "does not set 'target_message_id' to nil" do
                expect { result }.not_to change { context.target_message_id }
              end
            end

            context "when guardian is not staff" do
              it { is_expected.to be true }

              it "sets 'target_message_id' to nil" do
                expect { result }.to change { context.target_message_id }.to(nil)
              end
            end
          end
        end
      end
    end
  end
end
