# frozen_string_literal: true

RSpec.describe Chat::AutoRemove::HandleUserRemovedFromGroup do
  describe ".call" do
    subject(:result) { described_class.call(params) }

    let(:params) { { user_id: removed_user.id } }
    fab!(:removed_user) { Fabricate(:user) }
    fab!(:user_1) { Fabricate(:user) }
    fab!(:user_2) { Fabricate(:user) }

    fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [removed_user, user_1]) }
    fab!(:dm_channel_2) { Fabricate(:direct_message_channel, users: [removed_user, user_2]) }

    fab!(:public_channel_1) { Fabricate(:chat_channel) }
    fab!(:public_channel_2) { Fabricate(:chat_channel) }

    context "when chat is not enabled" do
      before { SiteSetting.chat_enabled = false }

      it { is_expected.to fail_a_policy(:chat_enabled) }
    end

    context "when chat is enabled" do
      before { SiteSetting.chat_enabled = true }

      context "if user is deleted" do
        before { removed_user.destroy! }

        it "fails to find the user model" do
          expect(result).to fail_to_find_a_model(:user)
        end
      end

      context "when the user is no longer in any of the chat_allowed_groups" do
        before do
          SiteSetting.chat_allowed_groups = Fabricate(:group).id
          public_channel_1.add(removed_user)
          public_channel_2.add(removed_user)
        end

        it "sets the service result as successful" do
          expect(result).to be_a_success
        end

        it "removes them from public channels" do
          expect { result }.to change {
            Chat::UserChatChannelMembership.where(
              user: [removed_user],
              chat_channel: [public_channel_1, public_channel_2],
            ).count
          }.to 0
        end

        it "does not remove them from direct message channels" do
          expect { result }.not_to change {
            Chat::UserChatChannelMembership.where(
              user: [removed_user],
              chat_channel: [dm_channel_1, dm_channel_2],
            ).count
          }
        end

        it "enqueues a job to kick each batch of users from the channel" do
          freeze_time
          result
          expect(
            job_enqueued?(
              job: Jobs::Chat::KickUsersFromChannel,
              at: 5.seconds.from_now,
              args: {
                user_ids: [removed_user.id],
                channel_id: public_channel_1.id,
              },
            ),
          ).to eq(true)
          expect(
            job_enqueued?(
              job: Jobs::Chat::KickUsersFromChannel,
              at: 5.seconds.from_now,
              args: {
                user_ids: [removed_user.id],
                channel_id: public_channel_2.id,
              },
            ),
          ).to eq(true)
        end

        it "logs staff actions" do
          result

          expect(
            UserHistory
              .where(
                acting_user_id: Discourse.system_user.id,
                custom_type: "chat_auto_remove_membership",
              )
              .last(2)
              .map(&:details),
          ).to contain_exactly(
            "users_removed: 1\nchannel_id: #{public_channel_1.id}\nevent: user_removed_from_group",
            "users_removed: 1\nchannel_id: #{public_channel_2.id}\nevent: user_removed_from_group",
          )
        end

        context "when the user is staff" do
          fab!(:removed_user) { Fabricate(:admin) }

          it { is_expected.to fail_a_policy(:user_not_staff) }

          it "does not remove them from public channels" do
            expect { result }.not_to change {
              Chat::UserChatChannelMembership.where(
                user: [removed_user],
                chat_channel: [public_channel_1, public_channel_2],
              ).count
            }
          end
        end

        context "when the only chat_allowed_group is everyone" do
          before { SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone] }

          it { is_expected.to fail_a_policy(:not_everyone_allowed) }

          it "does not remove them from public channels" do
            expect { result }.not_to change {
              Chat::UserChatChannelMembership.where(
                user: [removed_user],
                chat_channel: [public_channel_1, public_channel_2],
              ).count
            }
          end
        end
      end

      context "for private channels" do
        fab!(:group_1) { Fabricate(:group) }
        fab!(:group_2) { Fabricate(:group) }
        fab!(:private_category) { Fabricate(:private_category, group: group_1) }
        fab!(:private_channel_1) { Fabricate(:chat_channel, chatable: private_category) }

        before do
          group_1.add(removed_user)
          group_2.add(removed_user)
          SiteSetting.chat_allowed_groups = [group_1.id, group_2.id].join("|")
          CategoryGroup.create(
            category: private_category,
            group: group_2,
            permission_type: CategoryGroup.permission_types[:full],
          )
          private_channel_1.add(removed_user)
        end

        context "when the user remains in one of the groups that can access a private channel" do
          before { group_1.remove(removed_user) }

          it "sets the service result as successful" do
            expect(result).to be_a_success
          end

          it "does not remove them from that channel" do
            expect { result }.not_to change {
              Chat::UserChatChannelMembership.where(
                user: [removed_user],
                chat_channel: [private_channel_1],
              ).count
            }
          end
        end

        context "when the user in remains in one of the groups but that group only has readonly access to the channel" do
          before do
            CategoryGroup.find_by(group: group_2, category: private_category).update!(
              permission_type: CategoryGroup.permission_types[:readonly],
            )
            group_1.remove(removed_user)
          end

          it "sets the service result as successful" do
            expect(result).to be_a_success
          end

          it "removes them from that channel" do
            expect { result }.to change {
              Chat::UserChatChannelMembership.where(
                user: [removed_user],
                chat_channel: [private_channel_1],
              ).count
            }.to 0
          end

          context "when the user is staff" do
            fab!(:removed_user) { Fabricate(:admin) }

            it { is_expected.to fail_a_policy(:user_not_staff) }

            it "does not remove them from that channel" do
              expect { result }.not_to change {
                Chat::UserChatChannelMembership.where(
                  user: [removed_user],
                  chat_channel: [private_channel_1],
                ).count
              }
            end
          end
        end

        context "when the user is no longer in any group that can access a private channel" do
          before do
            group_1.remove(removed_user)
            group_2.remove(removed_user)
          end

          it "sets the service result as successful" do
            expect(result).to be_a_success
          end

          it "removes them from that channel" do
            expect { result }.to change {
              Chat::UserChatChannelMembership.where(
                user: [removed_user],
                chat_channel: [private_channel_1],
              ).count
            }.to 0
          end

          context "when the user is staff" do
            fab!(:removed_user) { Fabricate(:admin) }

            it { is_expected.to fail_a_policy(:user_not_staff) }

            it "does not remove them from that channel" do
              expect { result }.not_to change {
                Chat::UserChatChannelMembership.where(
                  user: [removed_user],
                  chat_channel: [private_channel_1],
                ).count
              }
            end
          end
        end
      end
    end
  end
end
