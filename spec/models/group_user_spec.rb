# frozen_string_literal: true

RSpec.describe GroupUser do
  fab!(:group)
  fab!(:user)

  describe "callbacks" do
    it "increments and decrements `Group#user_count` when record is created and destroyed" do
      group_user = GroupUser.new(user: user, group: group)

      expect do group_user.save! end.to change { group.reload.user_count }.from(0).to(1)

      expect do group_user.destroy! end.to change { group.reload.user_count }.from(1).to(0)
    end
  end

  it "correctly sets notification level" do
    moderator = Fabricate(:moderator)

    gu = GroupUser.find_by(user_id: moderator.id, group_id: Group::AUTO_GROUPS[:moderators])

    expect(gu.notification_level).to eq(NotificationLevels.all[:tracking])

    group = Group.create!(name: "bob")
    group.add(moderator)
    group.save

    gu = GroupUser.find_by(user_id: moderator.id, group_id: group.id)
    expect(gu.notification_level).to eq(NotificationLevels.all[:watching])

    group.remove(moderator)
    group.save

    group.default_notification_level = 1
    group.save

    group.add(moderator)
    group.save

    gu = GroupUser.find_by(user_id: moderator.id, group_id: group.id)
    expect(gu.notification_level).to eq(NotificationLevels.all[:regular])
  end

  describe "default category notifications" do
    fab!(:group)
    fab!(:user)
    fab!(:category1, :category)
    fab!(:category2, :category)
    fab!(:category3, :category)
    fab!(:category4, :category)
    fab!(:category5, :category)

    def levels
      CategoryUser.notification_levels
    end

    it "doesn't change anything with no configured defaults" do
      expect { group.add(user) }.to_not change { CategoryUser.count }
    end

    it "adds new category notifications" do
      group.muted_category_ids = [category1.id]
      group.regular_category_ids = [category2.id]
      group.tracking_category_ids = [category3.id]
      group.watching_category_ids = [category4.id]
      group.watching_first_post_category_ids = [category5.id]
      group.save!
      expect { group.add(user) }.to change { CategoryUser.count }.by(5)
      h = CategoryUser.notification_levels_for(user)
      expect(h[category1.id]).to eq(levels[:muted])
      expect(h[category2.id]).to eq(levels[:regular])
      expect(h[category3.id]).to eq(levels[:tracking])
      expect(h[category4.id]).to eq(levels[:watching])
      expect(h[category5.id]).to eq(levels[:watching_first_post])
    end

    it "only upgrades notifications" do
      CategoryUser.create!(
        user: user,
        category_id: category1.id,
        notification_level: levels[:muted],
      )
      CategoryUser.create!(
        user: user,
        category_id: category2.id,
        notification_level: levels[:tracking],
      )
      CategoryUser.create!(
        user: user,
        category_id: category3.id,
        notification_level: levels[:watching_first_post],
      )
      CategoryUser.create!(
        user: user,
        category_id: category4.id,
        notification_level: levels[:watching],
      )
      group.regular_category_ids = [category1.id]
      group.watching_first_post_category_ids = [category2.id, category3.id, category4.id]
      group.save!
      group.add(user)
      h = CategoryUser.notification_levels_for(user)
      expect(h[category1.id]).to eq(levels[:regular])
      expect(h[category2.id]).to eq(levels[:watching_first_post])
      expect(h[category3.id]).to eq(levels[:watching_first_post])
      expect(h[category4.id]).to eq(levels[:watching])
    end

    it "merges notifications" do
      CategoryUser.create!(
        user: user,
        category_id: category1.id,
        notification_level: CategoryUser.notification_levels[:tracking],
      )
      CategoryUser.create!(
        user: user,
        category_id: category2.id,
        notification_level: CategoryUser.notification_levels[:watching],
      )
      CategoryUser.create!(
        user: user,
        category_id: category4.id,
        notification_level: CategoryUser.notification_levels[:watching_first_post],
      )
      group.muted_category_ids = [category3.id]
      group.tracking_category_ids = [category4.id]
      group.save!
      group.add(user)
      h = CategoryUser.notification_levels_for(user)
      expect(h[category1.id]).to eq(levels[:tracking])
      expect(h[category2.id]).to eq(levels[:watching])
      expect(h[category3.id]).to eq(levels[:muted])
      expect(h[category4.id]).to eq(levels[:watching_first_post])
    end
  end

  describe "default tag notifications" do
    fab!(:group)
    fab!(:user)
    fab!(:tag1, :tag)
    fab!(:tag2, :tag)
    fab!(:tag3, :tag)
    fab!(:tag4, :tag)
    fab!(:tag5, :tag)
    fab!(:synonym1) { Fabricate(:tag, target_tag: tag1) }

    def levels
      TagUser.notification_levels
    end

    it "doesn't change anything with no configured defaults" do
      expect { group.add(user) }.to_not change { TagUser.count }
    end

    it "adds new tag notifications" do
      group.muted_tags = [synonym1.name]
      group.regular_tags = [tag2.name]
      group.tracking_tags = [tag3.name]
      group.watching_tags = [tag4.name]
      group.watching_first_post_tags = [tag5.name]
      group.save!
      expect { group.add(user) }.to change { TagUser.count }.by(5)
      expect(TagUser.lookup(user, :muted).pluck(:tag_id)).to eq([tag1.id])
      expect(TagUser.lookup(user, :regular).pluck(:tag_id)).to eq([tag2.id])
      expect(TagUser.lookup(user, :tracking).pluck(:tag_id)).to eq([tag3.id])
      expect(TagUser.lookup(user, :watching).pluck(:tag_id)).to eq([tag4.id])
      expect(TagUser.lookup(user, :watching_first_post).pluck(:tag_id)).to eq([tag5.id])
    end

    it "only upgrades notifications" do
      TagUser.create!(user: user, tag_id: tag1.id, notification_level: levels[:muted])
      TagUser.create!(user: user, tag_id: tag2.id, notification_level: levels[:tracking])
      TagUser.create!(user: user, tag_id: tag3.id, notification_level: levels[:watching_first_post])
      TagUser.create!(user: user, tag_id: tag4.id, notification_level: levels[:watching])
      group.regular_tags = [tag1.name]
      group.watching_first_post_tags = [tag2.name, tag3.name, tag4.name]
      group.save!
      group.add(user)
      expect(TagUser.lookup(user, :muted).pluck(:tag_id)).to be_empty
      expect(TagUser.lookup(user, :regular).pluck(:tag_id)).to eq([tag1.id])
      expect(TagUser.lookup(user, :tracking).pluck(:tag_id)).to be_empty
      expect(TagUser.lookup(user, :watching).pluck(:tag_id)).to eq([tag4.id])
      expect(TagUser.lookup(user, :watching_first_post).pluck(:tag_id)).to contain_exactly(
        tag2.id,
        tag3.id,
      )
    end

    it "merges notifications" do
      TagUser.create!(user: user, tag_id: tag1.id, notification_level: levels[:tracking])
      TagUser.create!(user: user, tag_id: tag2.id, notification_level: levels[:watching])
      TagUser.create!(user: user, tag_id: tag4.id, notification_level: levels[:watching_first_post])
      group.muted_tags = [tag3.name]
      group.tracking_tags = [tag2.name]
      group.save!
      group.add(user)
      expect(TagUser.lookup(user, :muted).pluck(:tag_id)).to eq([tag3.id])
      expect(TagUser.lookup(user, :tracking).pluck(:tag_id)).to eq([tag1.id])
      expect(TagUser.lookup(user, :watching).pluck(:tag_id)).to eq([tag2.id])
      expect(TagUser.lookup(user, :watching_first_post).pluck(:tag_id)).to eq([tag4.id])
    end
  end

  describe "#ensure_consistency!" do
    fab!(:group)
    fab!(:group_2, :group)

    fab!(:pm_post, :private_message_post)

    fab!(:pm_topic) { pm_post.topic.tap { |t| t.allowed_groups << group } }

    fab!(:user) do
      Fabricate(:user, last_seen_at: Time.zone.now).tap do |u|
        group.add(u)
        group_2.add(u)

        TopicUser.change(
          u.id,
          pm_topic.id,
          notification_level: TopicUser.notification_levels[:tracking],
          last_read_post_number: pm_post.post_number,
        )
      end
    end

    # User that is not tracking topic
    fab!(:user_2) do
      Fabricate(:user, last_seen_at: Time.zone.now).tap do |u|
        group.add(u)

        TopicUser.change(
          u.id,
          pm_topic.id,
          notification_level: TopicUser.notification_levels[:regular],
          last_read_post_number: pm_post.post_number,
        )
      end
    end

    # User that has not been seen
    fab!(:user_3) do
      Fabricate(:user).tap do |u|
        group.add(u)

        TopicUser.change(
          u.id,
          pm_topic.id,
          notification_level: TopicUser.notification_levels[:tracking],
          last_read_post_number: pm_post.post_number,
        )
      end
    end

    it "updates first unread pm timestamp correctly" do
      freeze_time 10.minutes.from_now

      post = create_post(user: pm_topic.user, topic_id: pm_topic.id)

      expect { GroupUser.ensure_consistency! }.to_not change {
        group.group_users.find_by(user_id: user_3.id).first_unread_pm_at
      }

      expect(post.topic.updated_at).to_not eq_time(10.minutes.ago)
      expect(group.group_users.find_by(user_id: user.id).first_unread_pm_at).to eq_time(
        post.topic.updated_at,
      )
      expect(group_2.group_users.find_by(user_id: user.id).first_unread_pm_at).to eq_time(
        10.minutes.ago,
      )
      expect(group.group_users.find_by(user_id: user_2.id).first_unread_pm_at).to eq_time(
        10.minutes.ago,
      )
    end
  end

  describe "#destroy!" do
    fab!(:group)

    it "removes `primary_group_id`, `flair_group_id` and exec `match_primary_group_changes` method on user model" do
      user = Fabricate(:user, primary_group: group, flair_group: group)
      group_user = Fabricate(:group_user, group: group, user: user)

      user.expects(:match_primary_group_changes).once
      group_user.destroy!

      user.reload
      expect(user.primary_group_id).to be_nil
      expect(user.flair_group_id).to be_nil
    end

    it "restores previous trust level" do
      user = Fabricate(:user)
      expect(user.trust_level).to eq(1)

      user.change_trust_level!(1, log_action_for: Discourse.system_user)
      user.change_trust_level!(2, log_action_for: Discourse.system_user)
      group.update!(grant_trust_level: 4)

      group_user = Fabricate(:group_user, group: group, user: user)
      expect(user.reload.trust_level).to eq(4)
      expect(user.groups.where(automatic: true).map(&:name)).to contain_exactly(
        "trust_level_0",
        "trust_level_1",
        "trust_level_2",
        "trust_level_3",
        "trust_level_4",
      )

      group_user.destroy!
      # keep in mind that we do not restore tl3, cause reqs can be lost
      expect(user.reload.trust_level).to eq(2)
      expect(user.groups.where(automatic: true).map(&:name)).to contain_exactly(
        "trust_level_0",
        "trust_level_1",
        "trust_level_2",
      )
    end

    it "protects user trust level if all requirements are met" do
      Promotion.stubs(:tl2_met?).returns(true)

      user = Fabricate(:user)
      expect(user.trust_level).to eq(1)

      group.update!(grant_trust_level: 1)

      Promotion.recalculate(user)
      expect(user.reload.trust_level).to eq(2)

      group_user = Fabricate(:group_user, group: group, user: user)
      expect_not_enqueued_with(
        job: :send_system_message,
        args: {
          user_id: user.id,
          message_type: "tl2_promotion_message",
        },
      ) { group_user.destroy! }
      expect(user.reload.trust_level).to eq(2)
    end
  end
end
