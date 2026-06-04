# frozen_string_literal: true

RSpec.describe Jobs::NotifyReviewable do
  describe "#execute" do
    fab!(:admin) { Fabricate(:admin, moderator: true) }
    fab!(:moderator)
    fab!(:group_user)
    fab!(:group) { group_user.group }
    fab!(:user) { group_user.user }

    it "will notify users of new reviewable content for the user menu" do
      SiteSetting.navigation_menu = "sidebar"
      SiteSetting.enable_category_group_moderation = true

      GroupUser.create!(group_id: group.id, user_id: moderator.id)

      # Content for admins only
      admin_reviewable = Fabricate(:reviewable, reviewable_by_moderator: false)
      admin.update!(last_seen_reviewable_id: admin_reviewable.id)

      messages =
        MessageBus.track_publish { described_class.new.execute(reviewable_id: admin_reviewable.id) }

      expect(messages.size).to eq(1)

      admin_message = messages.first

      expect(admin_message.channel).to eq("/reviewable_counts/#{admin.id}")
      expect(admin_message.user_ids).to eq([admin.id])
      expect(admin_message.data[:reviewable_count]).to eq(1)
      expect(admin_message.data[:unseen_reviewable_count]).to eq(0)

      # Content for moderators
      moderator_reviewable = Fabricate(:reviewable, reviewable_by_moderator: true)
      reviewed_moderator_reviewable = Fabricate(:reviewable, reviewable_by_moderator: true)
      reviewed_moderator_reviewable.update!(status: :approved)
      removed_moderator_reviewable = Fabricate(:reviewable, reviewable_by_moderator: true)
      removed_moderator_reviewable_id = removed_moderator_reviewable.id
      removed_moderator_reviewable.destroy!

      messages =
        MessageBus.track_publish do
          described_class.new.execute(
            reviewable_id: moderator_reviewable.id,
            performing_username: moderator.username,
            updated_reviewable_ids: [reviewed_moderator_reviewable.id],
            remove_reviewable_ids: [removed_moderator_reviewable_id],
          )
        end
      expect(messages.size).to eq(2)

      admin_message = messages.find { |m| m.user_ids == [admin.id] }

      expect(admin_message.channel).to eq("/reviewable_counts/#{admin.id}")
      expect(admin_message.data[:reviewable_count]).to eq(2)
      expect(admin_message.data[:unseen_reviewable_count]).to eq(1)
      expect(admin_message.data[:updates][reviewed_moderator_reviewable.id]).to eq(
        last_performing_username: moderator.username,
        status: Reviewable.statuses[:approved],
      )
      expect(admin_message.data[:remove_reviewable_ids]).to contain_exactly(
        removed_moderator_reviewable_id,
      )

      moderator_message = messages.find { |m| m.user_ids == [moderator.id] }

      expect(moderator_message.channel).to eq("/reviewable_counts/#{moderator.id}")
      expect(moderator_message.data[:reviewable_count]).to eq(1)
      expect(moderator_message.data[:unseen_reviewable_count]).to eq(1)
      expect(moderator_message.data[:updates][reviewed_moderator_reviewable.id]).to eq(
        last_performing_username: moderator.username,
        status: Reviewable.statuses[:approved],
      )
      expect(moderator_message.data[:remove_reviewable_ids]).to contain_exactly(
        removed_moderator_reviewable_id,
      )

      moderator.update!(last_seen_reviewable_id: moderator_reviewable.id)

      # Content for a group
      category = Fabricate(:category)
      Fabricate(:category_moderation_group, category:, group:)
      group_reviewable = Fabricate(:reviewable, reviewable_by_moderator: true, category:)

      messages =
        MessageBus.track_publish { described_class.new.execute(reviewable_id: group_reviewable.id) }

      expect(messages.size).to eq(3)

      admin_message = messages.find { |m| m.user_ids == [admin.id] }

      expect(admin_message.channel).to eq("/reviewable_counts/#{admin.id}")
      expect(admin_message.data[:reviewable_count]).to eq(3)
      expect(admin_message.data[:unseen_reviewable_count]).to eq(2)

      moderator_message = messages.find { |m| m.user_ids == [moderator.id] }

      expect(moderator_message.channel).to eq("/reviewable_counts/#{moderator.id}")
      expect(moderator_message.data[:reviewable_count]).to eq(2)
      expect(moderator_message.data[:unseen_reviewable_count]).to eq(1)

      group_user_message = messages.find { |m| m.user_ids == [user.id] }

      expect(group_user_message.channel).to eq("/reviewable_counts/#{user.id}")
      expect(group_user_message.data[:reviewable_count]).to eq(1)
      expect(group_user_message.data[:unseen_reviewable_count]).to eq(1)
    end

    it "won't notify a group when disabled" do
      SiteSetting.enable_category_group_moderation = false

      GroupUser.create!(group_id: group.id, user_id: moderator.id)
      category = Fabricate(:category)
      Fabricate(:category_moderation_group, category:, group:)
      reviewable = Fabricate(:reviewable, reviewable_by_moderator: true, category:)

      messages =
        MessageBus.track_publish("/reviewable_counts") do
          described_class.new.execute(reviewable_id: reviewable.id)
        end

      group_user_message = messages.find { |m| m.user_ids.include?(user.id) }

      expect(group_user_message).to be_blank
    end
  end
end
