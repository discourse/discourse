# frozen_string_literal: true

require 'rails_helper'

describe Jobs::NotifyReviewable do
  describe '.execute' do
    fab!(:admin) { Fabricate(:admin, moderator: true) }
    fab!(:moderator) { Fabricate(:moderator) }
    fab!(:group_user) { Fabricate(:group_user) }
    let(:user) { group_user.user }
    let(:group) { group_user.group }

    it "will notify users of new reviewable content" do
      SiteSetting.enable_category_group_review = true

      GroupUser.create!(group_id: group.id, user_id: moderator.id)

      # Content for admins only
      r1 = Fabricate(:reviewable, reviewable_by_moderator: false)
      messages = MessageBus.track_publish("/reviewable_counts") do
        described_class.new.execute(reviewable_id: r1.id)
      end
      admin_msg = messages.find { |m| m.user_ids.include?(admin.id) }
      expect(admin_msg.data[:reviewable_count]).to eq(1)
      expect(messages.any? { |m| m.user_ids.include?(moderator.id) }).to eq(false)
      expect(messages.any? { |m| m.user_ids.include?(user.id) }).to eq(false)

      # Content for moderators
      r2 = Fabricate(:reviewable, reviewable_by_moderator: true)
      messages = MessageBus.track_publish("/reviewable_counts") do
        described_class.new.execute(reviewable_id: r2.id)
      end
      admin_msg = messages.find { |m| m.user_ids.include?(admin.id) }
      expect(admin_msg.data[:reviewable_count]).to eq(2)
      mod_msg = messages.find { |m| m.user_ids.include?(moderator.id) }
      expect(mod_msg.data[:reviewable_count]).to eq(1)
      expect(mod_msg.user_ids).to_not include(admin.id)
      expect(messages.any? { |m| m.user_ids.include?(user.id) }).to eq(false)

      # Content for a group
      r3 = Fabricate(:reviewable, reviewable_by_moderator: true, reviewable_by_group: group)
      messages = MessageBus.track_publish("/reviewable_counts") do
        described_class.new.execute(reviewable_id: r3.id)
      end
      admin_msg = messages.find { |m| m.user_ids.include?(admin.id) }
      expect(admin_msg.data[:reviewable_count]).to eq(3)
      mod_messages = messages.select { |m| m.user_ids.include?(moderator.id) }
      expect(mod_messages.size).to eq(1)
      expect(mod_messages[0].data[:reviewable_count]).to eq(2)
      group_msg = messages.find { |m| m.user_ids.include?(user.id) }
      expect(group_msg.data[:reviewable_count]).to eq(1)
    end

    it "won't notify a group when disabled" do
      SiteSetting.enable_category_group_review = false

      GroupUser.create!(group_id: group.id, user_id: moderator.id)
      r3 = Fabricate(:reviewable, reviewable_by_moderator: true, reviewable_by_group: group)
      messages = MessageBus.track_publish("/reviewable_counts") do
        described_class.new.execute(reviewable_id: r3.id)
      end
      group_msg = messages.find { |m| m.user_ids.include?(user.id) }
      expect(group_msg).to be_blank
    end

    it "respects visibility" do
      SiteSetting.enable_category_group_review = true
      Reviewable.set_priorities(medium: 2.0)
      SiteSetting.reviewable_default_visibility = 'medium'

      GroupUser.create!(group_id: group.id, user_id: moderator.id)

      # Content for admins only
      r1 = Fabricate(:reviewable, reviewable_by_moderator: false)
      messages = MessageBus.track_publish("/reviewable_counts") do
        described_class.new.execute(reviewable_id: r1.id)
      end
      admin_msg = messages.find { |m| m.user_ids.include?(admin.id) }
      expect(admin_msg.data[:reviewable_count]).to eq(0)

      # Content for moderators
      r2 = Fabricate(:reviewable, reviewable_by_moderator: true)
      messages = MessageBus.track_publish("/reviewable_counts") do
        described_class.new.execute(reviewable_id: r2.id)
      end
      admin_msg = messages.find { |m| m.user_ids.include?(admin.id) }
      expect(admin_msg.data[:reviewable_count]).to eq(0)
      mod_msg = messages.find { |m| m.user_ids.include?(moderator.id) }
      expect(mod_msg.data[:reviewable_count]).to eq(0)

      # Content for a group
      r3 = Fabricate(:reviewable, reviewable_by_moderator: true, reviewable_by_group: group)
      messages = MessageBus.track_publish("/reviewable_counts") do
        described_class.new.execute(reviewable_id: r3.id)
      end
      admin_msg = messages.find { |m| m.user_ids.include?(admin.id) }
      expect(admin_msg.data[:reviewable_count]).to eq(0)
      mod_messages = messages.select { |m| m.user_ids.include?(moderator.id) }
      expect(mod_messages.size).to eq(1)
      expect(mod_messages[0].data[:reviewable_count]).to eq(0)
      group_msg = messages.find { |m| m.user_ids.include?(user.id) }
      expect(group_msg.data[:reviewable_count]).to eq(0)
    end
  end
end
