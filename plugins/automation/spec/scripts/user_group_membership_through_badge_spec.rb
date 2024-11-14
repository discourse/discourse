# frozen_string_literal: true

describe "UserGroupMembershipThroughBadge" do
  fab!(:user)
  fab!(:other_users) { Fabricate.times(5, :user) }
  fab!(:badge)
  fab!(:target_group) { Fabricate(:group, title: "Target Title", flair_icon: "ad") }

  fab!(:automation) do
    Fabricate(
      :automation,
      script: DiscourseAutomation::Scripts::USER_GROUP_MEMBERSHIP_THROUGH_BADGE,
    )
  end

  before { BadgeGranter.enable_queue }
  after do
    BadgeGranter.disable_queue
    BadgeGranter.clear_queue!
  end

  def target_group_member?(user_ids)
    GroupUser.exists?(group_id: target_group.id, user_id: user_ids)
  end

  def owns_badge?(user_ids)
    UserBadge.exists?(user_id: user_ids, badge_id: badge.id)
  end

  context "with invalid field values" do
    let(:fake_logger) { FakeLogger.new }

    before { Rails.logger.broadcast_to(fake_logger) }

    after { Rails.logger.stop_broadcasting_to(fake_logger) }

    context "with an unknown badge" do
      let(:unknown_badge_id) { -1 }

      before do
        automation.upsert_field!("badge", "choices", { value: unknown_badge_id }, target: "script")
        automation.trigger!(
          "kind" => DiscourseAutomation::Triggers::USER_FIRST_LOGGED_IN,
          "user" => user,
        )
      end

      it "logs warning message and does nothing" do
        expect(fake_logger.warnings).to include(
          "[discourse-automation] Couldn’t find badge with id #{unknown_badge_id}",
        )
        expect(user.reload.groups).to be_empty
      end
    end

    context "with a non-existent group" do
      before do
        automation.upsert_field!("badge", "choices", { value: badge.id }, target: "script")
        automation.upsert_field!("group", "group", { value: target_group.id }, target: "script")
      end

      it "logs warning message and does nothing" do
        target_group.destroy

        automation.trigger!(
          "kind" => DiscourseAutomation::Triggers::USER_FIRST_LOGGED_IN,
          "user" => user,
        )

        expect(fake_logger.warnings).to include(
          "[discourse-automation] Couldn’t find group with id #{target_group.id}",
        )
        expect(user.reload.groups).to be_empty
      end
    end
  end

  context "with valid field values" do
    before do
      automation.upsert_field!("badge", "choices", { value: badge.id }, target: "script")
      automation.upsert_field!("group", "group", { value: target_group.id }, target: "script")
    end

    context "when triggered with a user" do
      context "when user has badge" do
        before { BadgeGranter.grant(badge, user) }

        it "adds user to group" do
          expect(target_group_member?([user.id])).to eq(false)

          expect do
            automation.trigger!(
              "kind" => DiscourseAutomation::Triggers::USER_FIRST_LOGGED_IN,
              "user" => user,
            )
          end.to change { target_group.users.count }.by(1)

          expect(target_group_member?([user.id])).to eq(true)
          expect(owns_badge?([user.id])).to eq(true)
        end

        it "does nothing if user is an existing group member" do
          target_group.add(user)
          user.reload
          current_membership = user.group_users.find_by(group_id: target_group.id)

          expect(current_membership).not_to be_nil

          expect do
            automation.trigger!(
              "kind" => DiscourseAutomation::Triggers::USER_FIRST_LOGGED_IN,
              "user" => user,
            )
          end.not_to change { target_group.reload.users.count }

          expect(GroupUser.find_by(group_id: target_group.id, user_id: user.id)).to eq(
            current_membership,
          )
          expect(owns_badge?([user.id])).to eq(true)
        end

        it "does not add other badge owners" do
          other_users.each { |u| BadgeGranter.grant(badge, u) }

          expect(badge.user_badges.count).to eq(6)
          expect(target_group.users.count).to eq(0)

          expect do
            automation.trigger!(
              "kind" => DiscourseAutomation::Triggers::USER_FIRST_LOGGED_IN,
              "user" => user,
            )
          end.to change { target_group.reload.users.count }.by(1)

          expect(target_group_member?([user.id])).to eq(true)
          expect(owns_badge?([user.id])).to eq(true)
        end
      end

      context "when user does not have badge" do
        it "does not add user to group" do
          expect(target_group_member?([user.id])).to eq(false)
          expect(owns_badge?([user.id])).to eq(false)

          expect do
            automation.trigger!(
              "kind" => DiscourseAutomation::Triggers::USER_FIRST_LOGGED_IN,
              "user" => user,
            )
          end.not_to change { target_group.users.count }

          expect(target_group_member?([user.id])).to eq(false)
          expect(owns_badge?([user.id])).to eq(false)
        end

        it "does not add other badge owners" do
          other_users.each { |u| BadgeGranter.grant(badge, u) }

          expect(badge.user_badges.count).to eq(5)
          expect(target_group.users.count).to eq(0)

          expect do
            automation.trigger!(
              "kind" => DiscourseAutomation::Triggers::USER_FIRST_LOGGED_IN,
              "user" => user,
            )
          end.not_to change { target_group.reload.users.count }

          expect(target_group_member?([user.id])).to eq(false)
          expect(owns_badge?([user.id])).to eq(false)
          expect(target_group.users.count).to eq(0)
        end
      end
    end

    context "when triggered without a user" do
      let(:badge_owners) { other_users.first(3) }
      let(:non_badge_owners) { other_users.last(2) }
      let(:badge_owner_ids) { badge_owners.map(&:id) }
      let(:non_badge_owner_ids) { non_badge_owners.map(&:id) }

      before { badge_owners.each { |u| BadgeGranter.grant(badge, u) } }

      it "adds all users with badge to group" do
        expect(target_group_member?(badge_owner_ids)).to eq(false)
        expect(target_group_member?(non_badge_owner_ids)).to eq(false)

        expect do
          automation.trigger!("kind" => DiscourseAutomation::Triggers::RECURRING)
        end.to change { target_group.reload.users.count }.by(badge_owners.size)

        expect(target_group_member?(badge_owner_ids)).to eq(true)
        expect(target_group_member?(non_badge_owner_ids)).to eq(false)
      end

      it "skips existing group members with badge" do
        badge_owners.each { |u| target_group.add(u) }

        expect(target_group_member?(badge_owner_ids)).to eq(true)
        expect(target_group_member?(non_badge_owner_ids)).to eq(false)

        expect do
          automation.trigger!("kind" => DiscourseAutomation::Triggers::RECURRING)
        end.not_to change { target_group.reload.users.count }

        expect(target_group_member?(badge_owner_ids)).to eq(true)
        expect(target_group_member?(non_badge_owner_ids)).to eq(false)
      end
    end

    context "with remove_members_without_badge = true" do
      before do
        automation.upsert_field!(
          "remove_members_without_badge",
          "boolean",
          { value: true },
          target: "script",
        )
        other_users.each { |u| target_group.add(u) }
      end

      it "removes existing members without badge" do
        expect(target_group_member?(other_users.map(&:id))).to eq(true)

        expect do
          automation.trigger!("kind" => DiscourseAutomation::Triggers::RECURRING)
        end.to change { target_group.reload.users.count }.by(-other_users.count)

        expect(target_group_member?(other_users.map(&:id))).to eq(false)
      end

      it "keeps existing members with badge" do
        BadgeGranter.grant(badge, user)
        target_group.add(user)

        expect(target_group_member?(other_users.map(&:id))).to eq(true)
        expect(owns_badge?(other_users.map(&:id))).to eq(false)
        expect(target_group_member?([user.id])).to eq(true)
        expect(owns_badge?([user.id])).to eq(true)

        expect do
          automation.trigger!("kind" => DiscourseAutomation::Triggers::RECURRING)
        end.to change { target_group.reload.users.count }

        expect(target_group_member?(other_users.map(&:id))).to eq(false)
        expect(owns_badge?(other_users.map(&:id))).to eq(false)
        expect(target_group_member?([user.id])).to eq(true)
        expect(owns_badge?([user.id])).to eq(true)
      end
    end

    context "with remove_members_without_badge = false" do
      before do
        automation.upsert_field!(
          "remove_members_without_badge",
          "boolean",
          { value: false },
          target: "script",
        )
      end

      it "keeps existing members without badge" do
        other_users.each { |u| target_group.add(u) }

        expect(target_group_member?(other_users.map(&:id))).to eq(true)
        expect(owns_badge?(other_users.map(&:id))).to eq(false)

        expect do
          automation.trigger!("kind" => DiscourseAutomation::Triggers::RECURRING)
        end.not_to change { target_group.reload.users.count }

        expect(target_group_member?(other_users.map(&:id))).to eq(true)
        expect(owns_badge?(other_users.map(&:id))).to eq(false)
      end
    end

    context "with update_user_title_and_flair = true" do
      before do
        BadgeGranter.grant(badge, user)
        automation.upsert_field!(
          "update_user_title_and_flair",
          "boolean",
          { value: true },
          target: "script",
        )
      end

      it "sets user title and flair" do
        expect(user.title).to be_nil
        expect(user.flair_group_id).to be_nil

        automation.trigger!(
          "kind" => DiscourseAutomation::Triggers::USER_FIRST_LOGGED_IN,
          "user" => user,
        )

        user.reload
        expect(user.title).to eq("Target Title")
        expect(user.flair_group_id).to eq(target_group.id)
      end

      it "updates existing user title and flair" do
        existing_flair_group = Fabricate(:group)
        user.update(title: "Existing Title", flair_group_id: existing_flair_group.id)

        expect(user.title).to eq("Existing Title")
        expect(user.flair_group_id).to eq(existing_flair_group.id)

        automation.trigger!(
          "kind" => DiscourseAutomation::Triggers::USER_FIRST_LOGGED_IN,
          "user" => user,
        )

        user.reload
        expect(user.title).to eq("Target Title")
        expect(user.flair_group_id).to eq(target_group.id)

        user_badge = UserBadge.find_by(user_id: user.id, badge_id: badge.id)
        user_badge.destroy

        automation.upsert_field!(
          "remove_members_without_badge",
          "boolean",
          { value: true },
          target: "script",
        )

        automation.trigger!(
          "kind" => DiscourseAutomation::Triggers::USER_FIRST_LOGGED_IN,
          "user" => user,
        )

        user.reload
        expect(user.title).to be_nil
        expect(user.flair_group_id).to be_nil
      end
    end

    context "with update_user_title_and_flair = false" do
      before do
        BadgeGranter.grant(badge, user)
        automation.upsert_field!(
          "update_user_title_and_flair",
          "boolean",
          { value: false },
          target: "script",
        )
      end

      it "does not update existing user title and flair" do
        existing_flair_group = Fabricate(:group)
        user.update(title: "Existing Title", flair_group_id: existing_flair_group.id)

        expect(user.title).to eq("Existing Title")
        expect(user.flair_group_id).to eq(existing_flair_group.id)

        automation.trigger!(
          "kind" => DiscourseAutomation::Triggers::USER_FIRST_LOGGED_IN,
          "user" => user,
        )

        user.reload
        expect(user.title).to eq("Existing Title")
        expect(user.flair_group_id).to eq(existing_flair_group.id)

        user_badge = UserBadge.find_by(user_id: user.id, badge_id: badge.id)
        user_badge.destroy

        automation.upsert_field!(
          "remove_members_without_badge",
          "boolean",
          { value: true },
          target: "script",
        )

        automation.trigger!(
          "kind" => DiscourseAutomation::Triggers::USER_FIRST_LOGGED_IN,
          "user" => user,
        )

        user.reload
        expect(user.title).to eq("Existing Title")
        expect(user.flair_group_id).to eq(existing_flair_group.id)
      end
    end
  end
end
