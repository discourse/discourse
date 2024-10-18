# frozen_string_literal: true

RSpec.describe Chat::AutoRemove::HandleCategoryUpdated do
  describe ".call" do
    subject(:result) { described_class.call(params) }

    let(:params) { { category_id: updated_category.id } }

    fab!(:updated_category) { Fabricate(:category) }
    fab!(:user_1) { Fabricate(:user) }
    fab!(:user_2) { Fabricate(:user) }
    fab!(:admin_1) { Fabricate(:admin) }
    fab!(:admin_2) { Fabricate(:admin) }
    fab!(:channel_1) { Fabricate(:chat_channel, chatable: updated_category) }
    fab!(:channel_2) { Fabricate(:chat_channel, chatable: updated_category) }

    context "when chat is not enabled" do
      before { SiteSetting.chat_enabled = false }

      it { is_expected.to fail_a_policy(:chat_enabled) }
    end

    context "when chat is enabled" do
      before { SiteSetting.chat_enabled = true }

      context "if the category is deleted" do
        before { updated_category.destroy! }

        it "fails to find category model" do
          expect(result).to fail_to_find_a_model(:category)
        end
      end

      context "when there are no channels associated with the category" do
        before do
          channel_1.destroy!
          channel_2.destroy!
        end

        it "fails to find category_channel_ids model" do
          expect(result).to fail_to_find_a_model(:category_channel_ids)
        end
      end

      context "when the category has no more category_group records" do
        before do
          [user_1, user_2, admin_1, admin_2].each do |user|
            channel_1.add(user)
            channel_2.add(user)
          end
          updated_category.category_groups.delete_all
        end

        it { is_expected.to run_successfully }

        it "does not kick any users since the default permission is Everyone (full)" do
          expect { result }.not_to change {
            Chat::UserChatChannelMembership.where(
              user: [user_1, user_2, admin_1, admin_2],
              chat_channel: [channel_1, channel_2],
            ).count
          }
        end
      end

      context "when the category still has category_group records" do
        before do
          [user_1, user_2, admin_1, admin_2].each do |user|
            channel_1.add(user)
            channel_2.add(user)
          end

          group_1 = Fabricate(:group)
          CategoryGroup.create(
            group: group_1,
            category: updated_category,
            permission_type: CategoryGroup.permission_types[:full],
          )

          group_2 = Fabricate(:group)
          CategoryGroup.create(
            group: group_2,
            category: updated_category,
            permission_type: CategoryGroup.permission_types[:readonly],
          )

          group_1.add(user_1)
          group_2.add(user_1)
        end

        it { is_expected.to run_successfully }

        it "kicks all regular users who are not in any groups with reply + see permissions" do
          expect { result }.to change {
            Chat::UserChatChannelMembership.where(
              user: [user_1, user_2],
              chat_channel: [channel_1, channel_2],
            ).count
          }.to 2
        end

        it "does not kick admin users who are not in any groups with reply + see permissions" do
          expect { result }.not_to change {
            Chat::UserChatChannelMembership.where(
              user: [admin_1, admin_2],
              chat_channel: [channel_1, channel_2],
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
                user_ids: [user_2.id],
                channel_id: channel_1.id,
              },
            ),
          ).to eq(true)

          expect(
            job_enqueued?(
              job: Jobs::Chat::KickUsersFromChannel,
              at: 5.seconds.from_now,
              args: {
                user_ids: [user_2.id],
                channel_id: channel_2.id,
              },
            ),
          ).to eq(true)
        end

        it "logs a staff action" do
          result

          changes =
            UserHistory
              .where(custom_type: "chat_auto_remove_membership")
              .all
              .map { |uh| uh.slice(:details, :acting_user_id) }

          expect(changes).to match_array(
            [
              {
                details: "users_removed: 1\nchannel_id: #{channel_1.id}\nevent: category_updated",
                acting_user_id: Discourse.system_user.id,
              },
              {
                details: "users_removed: 1\nchannel_id: #{channel_2.id}\nevent: category_updated",
                acting_user_id: Discourse.system_user.id,
              },
            ],
          )
        end
      end
    end
  end
end
