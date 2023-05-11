# frozen_string_literal: true

RSpec.describe Jobs::NotifyReviewable do
  # remove all the legacy stuff here when redesigned_user_menu_enabled is
  # removed
  describe "#execute" do
    fab!(:admin) { Fabricate(:admin, moderator: true) }
    fab!(:moderator) { Fabricate(:moderator) }
    fab!(:group_user) { Fabricate(:group_user) }
    fab!(:group) { group_user.group }
    fab!(:user) { group_user.user }

    it "will notify users of new reviewable content for the new user menu" do
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

      messages =
        MessageBus.track_publish do
          described_class.new.execute(reviewable_id: moderator_reviewable.id)
        end
      expect(messages.size).to eq(2)

      admin_message = messages.find { |m| m.user_ids == [admin.id] }

      expect(admin_message.channel).to eq("/reviewable_counts/#{admin.id}")
      expect(admin_message.data[:reviewable_count]).to eq(2)
      expect(admin_message.data[:unseen_reviewable_count]).to eq(1)

      moderator_message = messages.find { |m| m.user_ids == [moderator.id] }

      expect(moderator_message.channel).to eq("/reviewable_counts/#{moderator.id}")
      expect(moderator_message.data[:reviewable_count]).to eq(1)
      expect(moderator_message.data[:unseen_reviewable_count]).to eq(1)

      moderator.update!(last_seen_reviewable_id: moderator_reviewable.id)

      # Content for a group
      group_reviewable =
        Fabricate(:reviewable, reviewable_by_moderator: true, reviewable_by_group: group)

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

    it "will notify users of new reviewable content for the old user menu" do
      SiteSetting.navigation_menu = "legacy"
      SiteSetting.enable_new_notifications_menu = false
      SiteSetting.enable_category_group_moderation = true

      GroupUser.create!(group_id: group.id, user_id: moderator.id)

      # Content for admins only
      admin_reviewable = Fabricate(:reviewable, reviewable_by_moderator: false)
      admin.update!(last_seen_reviewable_id: admin_reviewable.id)

      messages =
        MessageBus.track_publish { described_class.new.execute(reviewable_id: admin_reviewable.id) }

      expect(messages.size).to eq(1)

      admin_message = messages.first

      expect(admin_message.channel).to eq("/reviewable_counts")
      expect(admin_message.user_ids).to eq([admin.id])
      expect(admin_message.data[:reviewable_count]).to eq(1)
      expect(admin_message.data.has_key?(:unseen_reviewable_count)).to eq(false)

      # Content for moderators
      moderator_reviewable = Fabricate(:reviewable, reviewable_by_moderator: true)

      messages =
        MessageBus.track_publish do
          described_class.new.execute(reviewable_id: moderator_reviewable.id)
        end

      expect(messages.size).to eq(2)

      admin_message = messages.find { |m| m.user_ids == [admin.id] }
      expect(admin_message.channel).to eq("/reviewable_counts")
      expect(admin_message.data[:reviewable_count]).to eq(2)
      expect(admin_message.data.has_key?(:unseen_reviewable_count)).to eq(false)

      moderator_message = messages.find { |m| m.user_ids == [moderator.id] }
      expect(moderator_message.channel).to eq("/reviewable_counts")
      expect(moderator_message.data[:reviewable_count]).to eq(1)
      expect(moderator_message.data.key?(:unseen_reviewable_count)).to eq(false)

      moderator.update!(last_seen_reviewable_id: moderator_reviewable.id)

      # Content for a group
      group_reviewable =
        Fabricate(:reviewable, reviewable_by_moderator: true, reviewable_by_group: group)

      messages =
        MessageBus.track_publish { described_class.new.execute(reviewable_id: group_reviewable.id) }

      expect(messages.size).to eq(3)

      admin_message = messages.find { |m| m.user_ids == [admin.id] }
      expect(admin_message.data[:reviewable_count]).to eq(3)
      expect(admin_message.channel).to eq("/reviewable_counts")
      expect(admin_message.data.key?(:unseen_reviewable_count)).to eq(false)

      moderator_message = messages.find { |m| m.user_ids == [moderator.id] }
      expect(moderator_message.data[:reviewable_count]).to eq(2)
      expect(moderator_message.channel).to eq("/reviewable_counts")
      expect(moderator_message.data.key?(:unseen_reviewable_count)).to eq(false)

      group_user_message = messages.find { |m| m.user_ids == [user.id] }
      expect(group_user_message.data[:reviewable_count]).to eq(1)
      expect(group_user_message.channel).to eq("/reviewable_counts")
      expect(group_user_message.data.key?(:unseen_reviewable_count)).to eq(false)
    end

    it "won't notify a group when disabled" do
      SiteSetting.enable_category_group_moderation = false

      GroupUser.create!(group_id: group.id, user_id: moderator.id)
      reviewable = Fabricate(:reviewable, reviewable_by_moderator: true, reviewable_by_group: group)

      messages =
        MessageBus.track_publish("/reviewable_counts") do
          described_class.new.execute(reviewable_id: reviewable.id)
        end

      group_user_message = messages.find { |m| m.user_ids.include?(user.id) }

      expect(group_user_message).to be_blank
    end

    it "respects priority" do
      SiteSetting.navigation_menu = "legacy"
      SiteSetting.enable_new_notifications_menu = false
      SiteSetting.enable_category_group_moderation = true
      Reviewable.set_priorities(medium: 2.0)
      SiteSetting.reviewable_default_visibility = "medium"

      GroupUser.create!(group_id: group.id, user_id: moderator.id)

      # Content for admins only
      admin_reviewable = Fabricate(:reviewable, reviewable_by_moderator: false)

      messages =
        MessageBus.track_publish("/reviewable_counts") do
          described_class.new.execute(reviewable_id: admin_reviewable.id)
        end

      admin_message = messages.find { |m| m.user_ids.include?(admin.id) }
      expect(admin_message.data[:reviewable_count]).to eq(0)

      # Content for moderators
      moderator_reviewable = Fabricate(:reviewable, reviewable_by_moderator: true)

      messages =
        MessageBus.track_publish("/reviewable_counts") do
          described_class.new.execute(reviewable_id: moderator_reviewable.id)
        end

      admin_message = messages.find { |m| m.user_ids.include?(admin.id) }

      expect(admin_message.data[:reviewable_count]).to eq(0)

      moderator_message = messages.find { |m| m.user_ids.include?(moderator.id) }
      expect(moderator_message.data[:reviewable_count]).to eq(0)

      # Content for a group
      group_reviewable =
        Fabricate(:reviewable, reviewable_by_moderator: true, reviewable_by_group: group)

      messages =
        MessageBus.track_publish("/reviewable_counts") do
          described_class.new.execute(reviewable_id: group_reviewable.id)
        end

      admin_message = messages.find { |m| m.user_ids.include?(admin.id) }
      expect(admin_message.data[:reviewable_count]).to eq(0)

      moderator_messages = messages.select { |m| m.user_ids.include?(moderator.id) }
      expect(moderator_messages.size).to eq(1)
      expect(moderator_messages[0].data[:reviewable_count]).to eq(0)

      group_user_message = messages.find { |m| m.user_ids.include?(user.id) }
      expect(group_user_message.data[:reviewable_count]).to eq(0)
    end
  end

  it "skips sending notifications if user_ids is empty" do
    SiteSetting.navigation_menu = "legacy"
    SiteSetting.enable_new_notifications_menu = false
    reviewable = Fabricate(:reviewable, reviewable_by_moderator: true)
    regular_user = Fabricate(:user)

    messages =
      MessageBus.track_publish("/reviewable_counts") do
        described_class.new.execute(reviewable_id: reviewable.id)
      end

    expect(messages.size).to eq(0)
  end
end
