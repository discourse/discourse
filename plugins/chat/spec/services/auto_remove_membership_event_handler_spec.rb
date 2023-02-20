# frozen_string_literal: true

RSpec.describe Chat::Service::AutoRemoveMembershipEventHandler do
  describe ".call" do
    let(:event_data) { {} }
    let(:params) { { event_type: event_type, event_data: event_data } }
    let(:success_stub) { stub(failure?: false, users_removed: 99) }
    subject(:result) { described_class.call(params) }

    context "when the event_type is invalid" do
      let(:event_type) { :user_transformed_into_frog }

      it { is_expected.to fail_a_contract }
    end

    context "when event_type is valid" do
      context "for chat_allowed_groups_changed event_type" do
        let(:event_type) { :chat_allowed_groups_changed }
        let(:event_data) { { new_allowed_groups: "1|11" } }

        it "calls OutsideChatAllowedGroups service" do
          Chat::Service::AutoRemove::OutsideChatAllowedGroups
            .expects(:call)
            .with(new_allowed_groups: event_data[:new_allowed_groups])
            .returns(success_stub)

          expect(result).to be_a_success
        end

        it "logs in the staff action log" do
          Chat::Service::AutoRemove::OutsideChatAllowedGroups.stubs(:call).returns(success_stub)
          expect(result).to be_a_success

          action = UserHistory.last
          expect(action.details).to eq("users_removed: 99\nevent: chat_allowed_groups_changed")
          expect(action.acting_user_id).to eq(Discourse.system_user.id)
          expect(action.custom_type).to eq("chat_auto_remove_membership")
        end

        context "when the sub-service fails" do
          before do
            Chat::Service::AutoRemove::OutsideChatAllowedGroups
              .expects(:call)
              .with(new_allowed_groups: event_data[:new_allowed_groups])
              .returns(stub(failure?: true, context: { "error" => "test" }))
          end

          it "fails this service too" do
            expect(result).to be_a_failure
          end
        end
      end

      context "for user_removed_from_group event_type" do
        let(:event_type) { :user_removed_from_group }
        let(:event_data) { { user_id: Fabricate(:user).id } }

        it "calls UserRemovedFromGroup service" do
          Chat::Service::AutoRemove::UserRemovedFromGroup
            .expects(:call)
            .with(user_id: event_data[:user_id])
            .returns(stub(failure?: false, users_removed: 99))
          expect(result).to be_a_success
        end
      end

      context "for category_updated event_type" do
        let(:event_type) { :category_updated }
        let(:event_data) { { category_id: Fabricate(:category).id } }

        it "calls CategoryUpdated service" do
          Chat::Service::AutoRemove::CategoryUpdated
            .expects(:call)
            .with(category_id: event_data[:category_id])
            .returns(stub(failure?: false, users_removed: 99))
          expect(result).to be_a_success
        end
      end
    end
  end
end
