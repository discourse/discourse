# frozen_string_literal: true

RSpec.describe Chat::Service::AutoRemove::HandleCategoryUpdated do
  describe ".call" do
    let(:params) { { category_id: updated_category.id } }
    subject(:result) { described_class.call(params) }

    fab!(:updated_category) { Fabricate(:category) }

    fab!(:user_1) { Fabricate(:user) }
    fab!(:user_2) { Fabricate(:user) }
    fab!(:admin_1) { Fabricate(:admin) }
    fab!(:admin_2) { Fabricate(:admin) }

    fab!(:channel_1) { Fabricate(:chat_channel, chatable: updated_category) }
    fab!(:channel_2) { Fabricate(:chat_channel, chatable: updated_category) }

    it "fails model if category is deleted" do
      updated_category.destroy!
      expect(result).to fail_to_find_a_model(:category)
    end

    it "does nothing when there are no channels associated with the category" do
      channel_1.destroy!
      channel_2.destroy!
      expect { result }.not_to change { UserChatChannelMembership.count }
    end

    context "when the category has no more category_group records" do
      before do
        [user_1, user_2, admin_1, admin_2].each do |user|
          channel_1.add(user)
          channel_2.add(user)
        end
        updated_category.category_groups.delete_all
      end

      it "does not kick regular users since the default permission is Everyone (full)" do
        expect(result).to be_a_success
        expect(
          UserChatChannelMembership.where(
            user: [user_1, user_2],
            chat_channel: [channel_1, channel_2],
          ).count,
        ).to eq(4)
      end

      it "does not kick staff users since the default permission is Everyone (full)" do
        expect(result).to be_a_success
        expect(
          UserChatChannelMembership.where(
            user: [admin_1, admin_2],
            chat_channel: [channel_1, channel_2],
          ).count,
        ).to eq(4)
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

      it "kicks all regular users who are not in any groups with reply + see permissions" do
        expect(result).to be_a_success
        expect(
          UserChatChannelMembership.where(
            user: [user_1, user_2],
            chat_channel: [channel_1, channel_2],
          ).count,
        ).to eq(2)
      end

      it "does not kick admin users who are not in any groups with reply + see permissions" do
        expect(result).to be_a_success
        expect(
          UserChatChannelMembership.where(
            user: [admin_1, admin_2],
            chat_channel: [channel_1, channel_2],
          ).count,
        ).to eq(4)
      end

      it "enqueues a job to kick each batch of users from the channel" do
        freeze_time
        expect(result).to be_a_success
        expect(
          job_enqueued?(
            job: :kick_users_from_channel,
            at: 5.seconds.from_now,
            args: {
              user_ids: [user_2.id],
              channel_id: channel_1.id,
            },
          ),
        ).to eq(true)
        expect(
          job_enqueued?(
            job: :kick_users_from_channel,
            at: 5.seconds.from_now,
            args: {
              user_ids: [user_2.id],
              channel_id: channel_2.id,
            },
          ),
        ).to eq(true)
      end

      it "logs a staff action" do
        expect(result).to be_a_success
        action = UserHistory.last
        expect(action.details).to eq(
          "users_removed: 1\nchannel_id: #{channel_2.id}\nevent: category_updated",
        )
        expect(action.acting_user_id).to eq(Discourse.system_user.id)
        expect(action.custom_type).to eq("chat_auto_remove_membership")
      end
    end
  end
end
