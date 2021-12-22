# frozen_string_literal: true

require 'rails_helper'

describe UserUpdater do
  fab!(:user) { Fabricate(:user) }
  fab!(:u1) { Fabricate(:user) }
  fab!(:u2) { Fabricate(:user) }
  fab!(:u3) { Fabricate(:user) }

  let(:acting_user) { Fabricate.build(:user) }

  describe '#update_muted_users' do
    it 'has no cross talk' do
      updater = UserUpdater.new(u1, u1)
      updater.update_muted_users("#{u2.username},#{u3.username}")

      updater = UserUpdater.new(u2, u2)
      updater.update_muted_users("#{u3.username},#{u1.username}")

      updater = UserUpdater.new(u3, u3)
      updater.update_muted_users("")

      expect(MutedUser.where(user_id: u2.id).pluck(:muted_user_id)).to match_array([u3.id, u1.id])
      expect(MutedUser.where(user_id: u1.id).pluck(:muted_user_id)).to match_array([u2.id, u3.id])
      expect(MutedUser.where(user_id: u3.id).count).to eq(0)
    end

    it 'excludes acting user' do
      updater = UserUpdater.new(u1, u1)
      updater.update_muted_users("#{u1.username},#{u2.username}")

      expect(MutedUser.where(muted_user_id: u2.id).pluck(:muted_user_id)).to match_array([u2.id])
    end
  end

  describe '#update' do
    fab!(:category) { Fabricate(:category) }
    fab!(:tag) { Fabricate(:tag) }
    fab!(:tag2) { Fabricate(:tag) }

    it 'saves user' do
      user = Fabricate(:user, name: 'Billy Bob')
      updater = UserUpdater.new(user, user)

      updater.update(name: 'Jim Tom')

      expect(user.reload.name).to eq 'Jim Tom'
    end

    it 'can update categories and tags' do
      updater = UserUpdater.new(user, user)
      updater.update(watched_tags: "#{tag.name},#{tag2.name}", muted_category_ids: [category.id])

      expect(TagUser.where(
        user_id: user.id,
        tag_id: tag.id,
        notification_level: TagUser.notification_levels[:watching]
      ).exists?).to eq(true)

      expect(TagUser.where(
        user_id: user.id,
        tag_id: tag2.id,
        notification_level: TagUser.notification_levels[:watching]
      ).exists?).to eq(true)

      expect(CategoryUser.where(
        user_id: user.id,
        category_id: category.id,
        notification_level: CategoryUser.notification_levels[:muted]
      ).count).to eq(1)
    end

    context "staged user" do
      let(:staged_user) { Fabricate(:staged) }

      context "allow_changing_staged_user_tracking is false" do
        before { SiteSetting.allow_changing_staged_user_tracking = false }

        it "doesn't update muted categories and watched tags" do
          updater = UserUpdater.new(Fabricate(:admin), staged_user)
          updater.update(watched_tags: "#{tag.name}", muted_category_ids: [category.id])
          expect(TagUser.exists?(user_id: staged_user.id)).to eq(false)
          expect(CategoryUser.exists?(user_id: staged_user.id)).to eq(false)
        end
      end

      context "allow_changing_staged_user_tracking is true" do
        before { SiteSetting.allow_changing_staged_user_tracking = true }

        it "updates muted categories and watched tags" do
          updater = UserUpdater.new(Fabricate(:admin), staged_user)
          updater.update(watched_tags: "#{tag.name}", muted_category_ids: [category.id])
          expect(TagUser.exists?(
            user_id: staged_user.id,
            tag_id: tag.id,
            notification_level: TagUser.notification_levels[:watching]
          )).to eq(true)

          expect(CategoryUser.exists?(
            user_id: staged_user.id,
            category_id: category.id,
            notification_level: CategoryUser.notification_levels[:muted]
          )).to eq(true)
        end
      end
    end

    it "doesn't remove notification prefs when updating something else" do
      TagUser.create!(user: user, tag: tag, notification_level: TagUser.notification_levels[:watching])
      CategoryUser.create!(user: user, category: category, notification_level: CategoryUser.notification_levels[:muted])

      updater = UserUpdater.new(acting_user, user)
      updater.update(name: "Steve Dave")

      expect(TagUser.where(user: user).count).to eq(1)
      expect(CategoryUser.where(user: user).count).to eq(1)
    end

    it 'updates various fields' do
      updater = UserUpdater.new(acting_user, user)
      date_of_birth = Time.zone.now
      SiteSetting.disable_mailing_list_mode = false

      theme = Fabricate(:theme, user_selectable: true)

      seq = user.user_option.theme_key_seq

      val = updater.update(
        bio_raw: 'my new bio',
        email_level: UserOption.email_level_types[:always],
        mailing_list_mode: true,
        digest_after_minutes: "45",
        new_topic_duration_minutes: 100,
        auto_track_topics_after_msecs: 101,
        notification_level_when_replying: 3,
        email_in_reply_to: false,
        date_of_birth: date_of_birth,
        theme_ids: [theme.id],
        allow_private_messages: false
      )

      expect(val).to be_truthy

      user.reload

      expect(user.user_profile.bio_raw).to eq 'my new bio'
      expect(user.user_option.email_level).to eq UserOption.email_level_types[:always]
      expect(user.user_option.mailing_list_mode).to eq true
      expect(user.user_option.digest_after_minutes).to eq 45
      expect(user.user_option.new_topic_duration_minutes).to eq 100
      expect(user.user_option.auto_track_topics_after_msecs).to eq 101
      expect(user.user_option.notification_level_when_replying).to eq 3
      expect(user.user_option.email_in_reply_to).to eq false
      expect(user.user_option.theme_ids.first).to eq theme.id
      expect(user.user_option.theme_key_seq).to eq(seq + 1)
      expect(user.user_option.allow_private_messages).to eq(false)
      expect(user.date_of_birth).to eq(date_of_birth.to_date)
    end

    it "allows user to update profile header when the user has required trust level" do
      user = Fabricate(:user, trust_level: 2)
      updater = UserUpdater.new(user, user)
      upload = Fabricate(:upload)
      SiteSetting.min_trust_level_to_allow_profile_background = 2
      val = updater.update(profile_background_upload_url: upload.url)
      expect(val).to be_truthy
      user.reload
      expect(user.profile_background_upload).to eq(upload)
      success = updater.update(profile_background_upload_url: "")
      expect(success).to eq(true)
      user.reload
      expect(user.profile_background_upload).to eq(nil)
    end

    it "allows user to update user card background when the user has required trust level" do
      user = Fabricate(:user, trust_level: 2)
      updater = UserUpdater.new(user, user)
      upload = Fabricate(:upload)
      SiteSetting.min_trust_level_to_allow_user_card_background = 2
      val = updater.update(card_background_upload_url: upload.url)
      expect(val).to be_truthy
      user.reload
      expect(user.card_background_upload).to eq(upload)
      success = updater.update(card_background_upload_url: "")
      expect(success).to eq(true)
      user.reload
      expect(user.card_background_upload).to eq(nil)
    end

    it "disables email_digests when enabling mailing_list_mode" do
      updater = UserUpdater.new(acting_user, user)
      SiteSetting.disable_mailing_list_mode = false

      val = updater.update(mailing_list_mode: true, email_digests: true)
      expect(val).to be_truthy

      user.reload

      expect(user.user_option.email_digests).to eq false
      expect(user.user_option.mailing_list_mode).to eq true
    end

    it "filters theme_ids blank values before updating preferences" do
      user.user_option.update!(theme_ids: [1])
      updater = UserUpdater.new(acting_user, user)

      updater.update(theme_ids: [""])
      user.reload
      expect(user.user_option.theme_ids).to eq([])

      updater.update(theme_ids: [nil])
      user.reload
      expect(user.user_option.theme_ids).to eq([])

      theme = Fabricate(:theme)
      child = Fabricate(:theme, component: true)
      theme.add_relative_theme!(:child, child)
      theme.set_default!

      updater.update(theme_ids: [theme.id.to_s, child.id.to_s, "", nil])
      user.reload
      expect(user.user_option.theme_ids).to eq([theme.id, child.id])
    end

    let(:schedule_attrs) {
      {
        enabled: true,
        day_0_start_time: 30,
        day_0_end_time: 60,
        day_1_start_time: 30,
        day_1_end_time: 60,
        day_2_start_time: 30,
        day_2_end_time: 60,
        day_3_start_time: 30,
        day_3_end_time: 60,
        day_4_start_time: 30,
        day_4_end_time: 60,
        day_5_start_time: 30,
        day_5_end_time: 60,
        day_6_start_time: 30,
        day_6_end_time: 60,
      }
    }

    context 'with user_notification_schedule' do
      it "allows users to create their notification schedule when it doesn't exist previously" do
        expect(user.user_notification_schedule).to be_nil
        updater = UserUpdater.new(acting_user, user)

        updater.update(user_notification_schedule: schedule_attrs)
        user.reload
        expect(user.user_notification_schedule.enabled).to eq(true)
        expect(user.user_notification_schedule.day_0_start_time).to eq(30)
        expect(user.user_notification_schedule.day_0_end_time).to eq(60)
        expect(user.user_notification_schedule.day_6_start_time).to eq(30)
        expect(user.user_notification_schedule.day_6_end_time).to eq(60)
      end

      it "allows users to update their notification schedule" do
        UserNotificationSchedule.create({
          user: user,
        }.merge(UserNotificationSchedule::DEFAULT))
        updater = UserUpdater.new(acting_user, user)
        updater.update(user_notification_schedule: schedule_attrs)
        user.reload
        expect(user.user_notification_schedule.enabled).to eq(true)
        expect(user.user_notification_schedule.day_0_start_time).to eq(30)
        expect(user.user_notification_schedule.day_0_end_time).to eq(60)
        expect(user.user_notification_schedule.day_6_start_time).to eq(30)
        expect(user.user_notification_schedule.day_6_end_time).to eq(60)
      end

      it "processes the schedule and do_not_disturb_timings are created" do
        updater = UserUpdater.new(acting_user, user)

        expect {
          updater.update(user_notification_schedule: schedule_attrs)
        }.to change { user.do_not_disturb_timings.count }.by(4)
      end

      it "removes do_not_disturb_timings when the schedule is disabled" do
        updater = UserUpdater.new(acting_user, user)
        updater.update(user_notification_schedule: schedule_attrs)
        expect(user.user_notification_schedule.enabled).to eq(true)

        schedule_attrs[:enabled] = false
        updater.update(user_notification_schedule: schedule_attrs)

        expect(user.user_notification_schedule.enabled).to eq(false)
        expect(user.do_not_disturb_timings.count).to eq(0)
      end
    end

    context 'when sso overrides bio' do
      it 'does not change bio' do
        SiteSetting.discourse_connect_url = "https://www.example.com/sso"
        SiteSetting.enable_discourse_connect = true
        SiteSetting.discourse_connect_overrides_bio = true

        updater = UserUpdater.new(acting_user, user)

        expect(updater.update(bio_raw: "new bio")).to be_truthy

        user.reload
        expect(user.user_profile.bio_raw).not_to eq 'new bio'
      end
    end

    context 'when sso overrides location' do
      it 'does not change location' do
        SiteSetting.discourse_connect_url = "https://www.example.com/sso"
        SiteSetting.enable_discourse_connect = true
        SiteSetting.discourse_connect_overrides_location = true

        updater = UserUpdater.new(acting_user, user)

        expect(updater.update(location: "new location")).to be_truthy

        user.reload
        expect(user.user_profile.location).not_to eq 'new location'
      end
    end

    context 'when sso overrides website' do
      it 'does not change website' do
        SiteSetting.discourse_connect_url = "https://www.example.com/sso"
        SiteSetting.enable_discourse_connect = true
        SiteSetting.discourse_connect_overrides_website = true

        updater = UserUpdater.new(acting_user, user)

        expect(updater.update(website: "https://google.com")).to be_truthy

        user.reload
        expect(user.user_profile.website).not_to eq 'https://google.com'
      end
    end

    context 'when updating primary group' do
      let(:new_group) { Group.create(name: 'new_group') }

      it 'updates when setting is enabled' do
        SiteSetting.user_selected_primary_groups = true
        user.groups << new_group
        user.update(primary_group_id: nil)
        UserUpdater.new(acting_user, user).update(primary_group_id: new_group.id)

        user.reload
        expect(user.primary_group_id).to eq new_group.id
      end

      it 'does not update when setting is disabled' do
        SiteSetting.user_selected_primary_groups = false
        user.groups << new_group
        user.update(primary_group_id: nil)
        UserUpdater.new(acting_user, user).update(primary_group_id: new_group.id)

        user.reload
        expect(user.primary_group_id).to eq nil
      end

      it 'does not update when changing other profile data' do
        SiteSetting.user_selected_primary_groups = true
        user.groups << new_group
        user.update(primary_group_id: new_group.id)
        UserUpdater.new(acting_user, user).update(website: 'http://example.com')

        user.reload
        expect(user.primary_group_id).to eq new_group.id
      end

      it 'can be removed by the user when setting is enabled' do
        SiteSetting.user_selected_primary_groups = true
        user.groups << new_group
        user.update(primary_group_id: new_group.id)
        UserUpdater.new(acting_user, user).update(primary_group_id: '')

        user.reload
        expect(user.primary_group_id).to eq nil
      end

      it 'cannot be removed by the user when setting is disabled' do
        SiteSetting.user_selected_primary_groups = false
        user.groups << new_group
        user.update(primary_group_id: new_group.id)
        UserUpdater.new(acting_user, user).update(primary_group_id: '')

        user.reload
        expect(user.primary_group_id).to eq new_group.id
      end
    end

    context 'when updating flair group' do
      let(:group) { Fabricate(:group, name: "Group", flair_bg_color: "#111111", flair_color: "#999999", flair_icon: "icon") }

      it 'updates when setting is enabled' do
        group.add(user)

        UserUpdater.new(acting_user, user).update(flair_group_id: group.id)
        expect(user.reload.flair_group_id).to eq(group.id)

        UserUpdater.new(acting_user, user).update(flair_group_id: "")
        expect(user.reload.flair_group_id).to eq(nil)
      end
    end

    context 'when update fails' do
      it 'returns false' do
        user.stubs(save: false)
        updater = UserUpdater.new(acting_user, user)

        expect(updater.update).to be_falsey
      end
    end

    context 'with permission to update title' do
      it 'allows user to change title' do
        user = Fabricate(:user, title: 'Emperor')
        Guardian.any_instance.stubs(:can_grant_title?).with(user, 'Minion').returns(true)
        updater = UserUpdater.new(acting_user, user)

        updater.update(title: 'Minion')

        expect(user.reload.title).to eq 'Minion'
      end
    end

    context 'title is from a badge' do
      fab!(:user) { Fabricate(:user, title: 'Emperor') }
      fab!(:badge) { Fabricate(:badge, name: 'Minion') }

      context 'badge can be used as a title' do
        before do
          badge.update(allow_title: true)
        end

        it 'can use as title, sets badge_granted_title' do
          BadgeGranter.grant(badge, user)
          updater = UserUpdater.new(user, user)
          updater.update(title: badge.name)
          user.reload
          expect(user.user_profile.badge_granted_title).to eq(true)
        end

        it 'badge has not been granted, does not change title' do
          badge.update(allow_title: true)
          updater = UserUpdater.new(user, user)
          updater.update(title: badge.name)
          user.reload
          expect(user.title).not_to eq(badge.name)
          expect(user.user_profile.badge_granted_title).to eq(false)
        end

        it 'changing to a title that is not from a badge, unsets badge_granted_title' do
          user.update(title: badge.name)
          user.user_profile.update(badge_granted_title: true)

          Guardian.any_instance.stubs(:can_grant_title?).with(user, 'Dancer').returns(true)

          updater = UserUpdater.new(user, user)
          updater.update(title: 'Dancer')
          user.reload
          expect(user.title).to eq('Dancer')
          expect(user.user_profile.badge_granted_title).to eq(false)
        end
      end

      it 'cannot use as title, does not change title' do
        BadgeGranter.grant(badge, user)
        updater = UserUpdater.new(user, user)
        updater.update(title: badge.name)
        user.reload
        expect(user.title).not_to eq(badge.name)
        expect(user.user_profile.badge_granted_title).to eq(false)
      end
    end

    context 'without permission to update title' do
      it 'does not allow user to change title' do
        user = Fabricate(:user, title: 'Emperor')
        Guardian.any_instance.stubs(:can_grant_title?).with(user, 'Minion').returns(false)
        updater = UserUpdater.new(acting_user, user)

        updater.update(title: 'Minion')

        expect(user.reload.title).not_to eq 'Minion'
      end
    end

    context 'when website includes http' do
      it 'does not add http before updating' do
        updater = UserUpdater.new(acting_user, user)

        updater.update(website: 'http://example.com')

        expect(user.reload.user_profile.website).to eq 'http://example.com'
      end
    end

    context 'when website does not include http' do
      it 'adds http before updating' do
        updater = UserUpdater.new(acting_user, user)

        updater.update(website: 'example.com')

        expect(user.reload.user_profile.website).to eq 'http://example.com'
      end
    end

    context 'when website is invalid' do
      it 'returns an error' do
        updater = UserUpdater.new(acting_user, user)

        expect(updater.update(website: 'ʔ<')).to eq nil
      end
    end

    context 'when custom_fields is empty string' do
      it "update is successful" do
        user.custom_fields = { 'import_username' => 'my_old_username' }
        user.save
        updater = UserUpdater.new(acting_user, user)

        updater.update(website: 'example.com', custom_fields: '')
        expect(user.reload.custom_fields).to eq('import_username' => 'my_old_username')
      end
    end

    it "logs the action" do
      user = Fabricate(:user, name: 'Billy Bob')

      expect do
        UserUpdater.new(user, user).update(name: 'Jim Tom')
      end.to change { UserHistory.count }.by(1)

      expect(UserHistory.last.action).to eq(
        UserHistory.actions[:change_name]
      )

      expect do
        UserUpdater.new(user, user).update(name: 'JiM TOm')
      end.to_not change { UserHistory.count }

      expect do
        UserUpdater.new(user, user).update(bio_raw: 'foo bar')
      end.to_not change { UserHistory.count }

      user_without_name = Fabricate(:user, name: nil)

      expect do
        UserUpdater.new(user_without_name, user_without_name).update(bio_raw: 'foo bar')
      end.to_not change { UserHistory.count }

      expect do
        UserUpdater.new(user_without_name, user_without_name).update(name: 'Jim Tom')
      end.to change { UserHistory.count }.by(1)

      expect(UserHistory.last.action).to eq(
        UserHistory.actions[:change_name]
      )

      expect do
        UserUpdater.new(user, user).update(name: '')
      end.to change { UserHistory.count }.by(1)

      expect(UserHistory.last.action).to eq(
        UserHistory.actions[:change_name]
      )
    end
  end
end
