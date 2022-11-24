# frozen_string_literal: true

RSpec.describe Jobs::RefreshUsersReviewableCounts do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:moderator) { Fabricate(:moderator) }
  fab!(:user) { Fabricate(:user) }

  fab!(:group) { Fabricate(:group) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:reviewable1) { Fabricate(:reviewable, reviewable_by_group: group, reviewable_by_moderator: true, topic: topic) }

  fab!(:reviewable2) { Fabricate(:reviewable, reviewable_by_moderator: false) }
  fab!(:reviewable3) { Fabricate(:reviewable, reviewable_by_moderator: true) }

  before do
    SiteSetting.enable_category_group_moderation = true
    group.add(user)
    topic.category.update!(reviewable_by_group: group)
  end

  describe '#execute' do
    it "publishes reviewable counts for the specified users" do
      messages = MessageBus.track_publish do
        described_class.new.execute(user_ids: [moderator.id, admin.id])
      end
      expect(messages.size).to eq(2)
      expect(messages.map(&:user_ids).flatten).to contain_exactly(moderator.id, admin.id)

      messages = MessageBus.track_publish do
        described_class.new.execute(user_ids: [moderator.id, user.id])
      end
      expect(messages.size).to eq(2)
      expect(messages.map(&:user_ids).flatten).to contain_exactly(moderator.id, user.id)
    end

    it "published counts respect reviewables visibility" do
      messages = MessageBus.track_publish do
        described_class.new.execute(user_ids: [moderator.id, admin.id, user.id])
      end
      expect(messages.size).to eq(3)

      admin_message = messages.find { |m| m.user_ids == [admin.id] }
      moderator_message = messages.find { |m| m.user_ids == [moderator.id] }
      user_message = messages.find { |m| m.user_ids == [user.id] }

      expect(admin_message.channel).to eq("/reviewable_counts/#{admin.id}")
      expect(admin_message.data).to eq(
        reviewable_count: 3,
        unseen_reviewable_count: 3
      )

      expect(moderator_message.channel).to eq("/reviewable_counts/#{moderator.id}")
      expect(moderator_message.data).to eq(
        reviewable_count: 2,
        unseen_reviewable_count: 2
      )

      expect(user_message.channel).to eq("/reviewable_counts/#{user.id}")
      expect(user_message.data).to eq(
        reviewable_count: 1,
        unseen_reviewable_count: 1
      )
    end
  end
end
