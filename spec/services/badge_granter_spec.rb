# frozen_string_literal: true

RSpec.describe BadgeGranter do
  fab!(:badge)
  fab!(:user)

  before { BadgeGranter.enable_queue }

  after do
    BadgeGranter.disable_queue
    BadgeGranter.clear_queue!
  end

  describe ".revoke_ungranted_titles!" do
    let(:user) { Fabricate(:user) }
    let(:other_user) { Fabricate(:user) }
    let(:badge) { Fabricate(:badge, allow_title: true) }

    it "can revoke title of a single user" do
      BadgeGranter.grant(badge, user)
      user.update!(title: badge.name)
      BadgeGranter.grant(badge, other_user)
      other_user.update!(title: badge.name)

      badge.update_column(:enabled, false)
      BadgeGranter.revoke_ungranted_titles!([user.id])

      expect(user.reload.title).to be_blank
      expect(other_user.reload.title).to eq(badge.name)
    end

    it "revokes title when badge is not allowed as title" do
      BadgeGranter.grant(badge, user)
      user.update!(title: badge.name)

      BadgeGranter.revoke_ungranted_titles!
      user.reload
      expect(user.title).to eq(badge.name)
      expect(user.user_profile.granted_title_badge_id).to eq(badge.id)

      badge.update_column(:allow_title, false)
      BadgeGranter.revoke_ungranted_titles!
      user.reload
      expect(user.title).to be_blank
      expect(user.user_profile.granted_title_badge_id).to be_nil
    end

    it "revokes title when badge is disabled" do
      BadgeGranter.grant(badge, user)
      user.update!(title: badge.name)

      BadgeGranter.revoke_ungranted_titles!
      user.reload
      expect(user.title).to eq(badge.name)
      expect(user.user_profile.granted_title_badge_id).to eq(badge.id)

      badge.update_column(:enabled, false)
      BadgeGranter.revoke_ungranted_titles!
      user.reload
      expect(user.title).to be_blank
      expect(user.user_profile.granted_title_badge_id).to be_nil
    end

    it "revokes title when user badge is revoked" do
      BadgeGranter.grant(badge, user)
      user.update!(title: badge.name)

      BadgeGranter.revoke_ungranted_titles!
      user.reload
      expect(user.title).to eq(badge.name)
      expect(user.user_profile.granted_title_badge_id).to eq(badge.id)

      BadgeGranter.revoke(user.user_badges.first)
      BadgeGranter.revoke_ungranted_titles!
      user.reload
      expect(user.title).to be_blank
      expect(user.user_profile.granted_title_badge_id).to be_nil
    end

    it "does not revoke custom title" do
      user.title = "CEO"
      user.save!

      BadgeGranter.revoke_ungranted_titles!

      user.reload
      expect(user.title).to eq("CEO")
    end

    it "does not revoke localized title" do
      badge = Badge.find(Badge::Regular)
      badge_name = nil
      BadgeGranter.grant(badge, user)

      I18n.with_locale(:de) do
        badge_name = badge.display_name
        user.update!(title: badge_name)
      end

      user.reload
      expect(user.title).to eq(badge_name)
      expect(user.user_profile.granted_title_badge_id).to eq(badge.id)

      BadgeGranter.revoke_ungranted_titles!
      user.reload
      expect(user.title).to eq(badge_name)
      expect(user.user_profile.granted_title_badge_id).to eq(badge.id)
    end
  end

  describe "preview" do
    it "can correctly preview" do
      Fabricate(:user, email: "sam@gmail.com")
      result =
        BadgeGranter.preview(
          'select u.id user_id, null post_id, u.created_at granted_at from users u
                                     join user_emails ue on ue.user_id = u.id AND ue.primary
                                     where ue.email like \'%gmail.com\'',
          explain: true,
        )

      expect(result[:grant_count]).to eq(1)
      expect(result[:query_plan]).to be_present
    end

    it "with badges containing trailing comments do not break generated SQL" do
      query = Badge.find(1).query + "\n-- a comment"
      expect(BadgeGranter.preview(query)[:errors]).to be_nil
    end
  end

  describe ".backfill" do
    it "has no broken badge queries" do
      Badge.all.each { |b| BadgeGranter.backfill(b) }
    end

    it "can backfill the welcome badge" do
      post = Fabricate(:post)
      user2 = Fabricate(:user)
      PostActionCreator.like(user2, post)

      UserBadge.destroy_all
      BadgeGranter.backfill(Badge.find(Badge::Welcome))
      BadgeGranter.backfill(Badge.find(Badge::FirstLike))

      b = UserBadge.find_by(user_id: post.user_id)
      expect(b.post_id).to eq(post.id)
      b.badge_id = Badge::Welcome

      b = UserBadge.find_by(user_id: user2.id)
      expect(b.post_id).to eq(post.id)
      b.badge_id = Badge::FirstLike
    end

    it "should grant missing badges" do
      nice_topic = Badge.find(Badge::NiceTopic)
      good_topic = Badge.find(Badge::GoodTopic)

      post = Fabricate(:post, like_count: 30)

      2.times do
        BadgeGranter.backfill(nice_topic, post_ids: [post.id])
        BadgeGranter.backfill(good_topic)
      end

      # TODO add welcome
      expect(post.user.user_badges.pluck(:badge_id)).to contain_exactly(
        nice_topic.id,
        good_topic.id,
      )
      expect(post.user.notifications.count).to eq(2)

      data = post.user.notifications.last.data_hash
      expect(data["badge_id"]).to eq(good_topic.id)
      expect(data["badge_slug"]).to eq(good_topic.slug)
      expect(data["username"]).to eq(post.user.username)

      expect(nice_topic.grant_count).to eq(1)
      expect(good_topic.grant_count).to eq(1)
    end

    it "should grant badges in the user locale" do
      SiteSetting.allow_user_locale = true

      nice_topic = Badge.find(Badge::NiceTopic)
      name_english = nice_topic.name

      user = Fabricate(:user, locale: "fr")
      post = Fabricate(:post, like_count: 10, user: user)

      BadgeGranter.backfill(nice_topic)

      notification_badge_name = JSON.parse(post.user.notifications.first.data)["badge_name"]

      expect(notification_badge_name).not_to eq(name_english)
    end

    it "with badges containing trailing comments do not break generated SQL" do
      badge = Fabricate(:badge)
      badge.query = Badge.find(1).query + "\n-- a comment"
      expect { BadgeGranter.backfill(badge) }.not_to raise_error
    end

    it 'does not notify about badges "for beginners" when user skipped new user tips' do
      user.user_option.update!(skip_new_user_tips: true)
      post = Fabricate(:post)
      PostActionCreator.like(user, post)

      expect { BadgeGranter.backfill(Badge.find(Badge::FirstLike)) }.to_not change {
        Notification.where(user_id: user.id).count
      }
    end

    it "does not grant sharing badges to deleted users" do
      post = Fabricate(:post)
      incoming_links = Fabricate.times(25, :incoming_link, post: post, user: user)
      user_id = user.id
      user.destroy!

      nice_share = Badge.find(Badge::NiceShare)
      first_share = Badge.find(Badge::FirstShare)

      BadgeGranter.backfill(nice_share)
      BadgeGranter.backfill(first_share)

      expect(UserBadge.where(user_id: user_id).count).to eq(0)
    end

    it "auto revokes badges from users when badge is set to auto revoke and user no longer satisfy the badge's query" do
      user.update!(username: "cool_username")

      badge_for_having_cool_username =
        Fabricate(
          :badge,
          query:
            "SELECT users.id user_id, CURRENT_TIMESTAMP granted_at FROM users WHERE users.username = 'cool_username'",
          auto_revoke: true,
        )

      granted_user_ids = []

      BadgeGranter.backfill(
        badge_for_having_cool_username,
        granted_callback: ->(user_ids) { granted_user_ids.concat(user_ids) },
      )

      expect(granted_user_ids).to eq([user.id])

      expect(
        UserBadge.exists?(user_id: user.id, badge_id: badge_for_having_cool_username.id),
      ).to eq(true)

      user.update!(username: "not_cool_username")

      revoked_user_ids = []

      BadgeGranter.backfill(
        badge_for_having_cool_username,
        revoked_callback: ->(user_ids) { revoked_user_ids.concat(user_ids) },
      )

      expect(revoked_user_ids).to eq([user.id])

      expect(
        UserBadge.exists?(user_id: user.id, badge_id: badge_for_having_cool_username.id),
      ).to eq(false)
    end
  end

  describe "grant" do
    it "allows overriding of granted_at does not notify old bronze" do
      freeze_time
      badge = Badge.create!(name: "a badge", badge_type_id: BadgeType::Bronze)
      user_badge = BadgeGranter.grant(badge, user, created_at: 1.year.ago)

      expect(user_badge.granted_at).to eq_time(1.year.ago)
      expect(Notification.where(user_id: user.id).count).to eq(0)
    end

    it "handles deleted badge" do
      freeze_time
      user_badge = BadgeGranter.grant(nil, user, created_at: 1.year.ago)
      expect(user_badge).to eq(nil)
    end

    it "doesn't grant disabled badges" do
      freeze_time
      badge = Fabricate(:badge, badge_type_id: BadgeType::Bronze, enabled: false)

      user_badge = BadgeGranter.grant(badge, user, created_at: 1.year.ago)
      expect(user_badge).to eq(nil)
    end

    it "doesn't notify about badges 'for beginners' when user skipped new user tips" do
      freeze_time
      UserBadge.destroy_all
      user.user_option.update!(skip_new_user_tips: true)
      badge = Fabricate(:badge, badge_grouping_id: BadgeGrouping::GettingStarted)

      expect { BadgeGranter.grant(badge, user) }.to_not change {
        Notification.where(user_id: user.id).count
      }
    end

    it "notifies about the New User of the Month badge when user skipped new user tips" do
      freeze_time
      user.user_option.update!(skip_new_user_tips: true)
      badge = Badge.find(Badge::NewUserOfTheMonth)

      expect { BadgeGranter.grant(badge, user) }.to change {
        Notification.where(user_id: user.id).count
      }
    end

    it "grants multiple badges" do
      badge = Fabricate(:badge, multiple_grant: true)
      user_badge = BadgeGranter.grant(badge, user)
      user_badge = BadgeGranter.grant(badge, user)
      expect(user_badge).to be_present

      expect(UserBadge.where(user_id: user.id).count).to eq(2)
    end

    it "updates is_favorite when granting multiple badges" do
      badge = Fabricate(:badge, multiple_grant: true)
      user_badge =
        UserBadge.create(
          badge: badge,
          user: user,
          granted_by: Discourse.system_user,
          granted_at: Time.now,
          is_favorite: true,
        )
      user_badge2 = BadgeGranter.grant(badge, user)

      expect(user_badge2).to be_present
      expect(user_badge2.reload.is_favorite).to eq(true)
    end

    it "sets granted_at" do
      day_ago = freeze_time 1.day.ago
      user_badge = BadgeGranter.grant(badge, user)

      expect(user_badge.granted_at).to eq_time(day_ago)
    end

    it "sets granted_by if the option is present" do
      admin = Fabricate(:admin)
      StaffActionLogger.any_instance.expects(:log_badge_grant).once
      user_badge = BadgeGranter.grant(badge, user, granted_by: admin)
      expect(user_badge.granted_by).to eq(admin)
    end

    it "defaults granted_by to the system user" do
      StaffActionLogger.any_instance.expects(:log_badge_grant).never
      user_badge = BadgeGranter.grant(badge, user)
      expect(user_badge.granted_by_id).to eq(Discourse.system_user.id)
    end

    it "does not allow a regular user to grant badges" do
      user_badge = BadgeGranter.grant(badge, user, granted_by: Fabricate(:user))
      expect(user_badge).not_to be_present
    end

    it "increments grant_count on the badge and creates a notification" do
      BadgeGranter.grant(badge, user)
      expect(badge.reload.grant_count).to eq(1)
      expect(
        user.notifications.find_by(notification_type: Notification.types[:granted_badge]).data_hash[
          "badge_id"
        ],
      ).to eq(badge.id)
    end

    it "does not fail when user is missing" do
      BadgeGranter.grant(badge, nil)
      expect(badge.reload.grant_count).to eq(0)
    end
  end

  describe "revoke" do
    fab!(:admin)
    let!(:user_badge) { BadgeGranter.grant(badge, user) }

    it "revokes the badge and does necessary cleanup" do
      user.title = badge.name
      user.save!
      expect(badge.reload.grant_count).to eq(1)
      StaffActionLogger.any_instance.expects(:log_badge_revoke).with(user_badge)
      BadgeGranter.revoke(user_badge, revoked_by: admin)
      expect(UserBadge.find_by(user: user, badge: badge)).not_to be_present
      expect(badge.reload.grant_count).to eq(0)
      expect(
        user.notifications.where(notification_type: Notification.types[:granted_badge]),
      ).to be_empty
      expect(user.reload.title).to eq(nil)
    end

    context "when the badge name is customized, and the customized name is the same as the user title" do
      let(:customized_badge_name) { "Merit Badge" }

      before do
        I18n.backend.store_translations(
          :en,
          { badges: { Badge.i18n_name(badge.name) => { name: "Badge 0" } } },
        )
        TranslationOverride.upsert!(I18n.locale, Badge.i18n_key(badge.name), customized_badge_name)
      end

      it "revokes the badge and title and does necessary cleanup" do
        user.title = customized_badge_name
        user.save!
        expect(badge.reload.grant_count).to eq(1)
        StaffActionLogger.any_instance.expects(:log_badge_revoke).with(user_badge)
        StaffActionLogger
          .any_instance
          .expects(:log_title_revoke)
          .with(
            user,
            revoke_reason: "user title was same as revoked badge name or custom badge name",
            previous_value: user_badge.user.title,
          )
        BadgeGranter.revoke(user_badge, revoked_by: admin)
        expect(UserBadge.find_by(user: user, badge: badge)).not_to be_present
        expect(badge.reload.grant_count).to eq(0)
        expect(
          user.notifications.where(notification_type: Notification.types[:granted_badge]),
        ).to be_empty
        expect(user.reload.title).to eq(nil)
      end

      after { TranslationOverride.revert!(I18n.locale, Badge.i18n_key(badge.name)) }
    end
  end

  describe "revoke_all" do
    it "deletes every user_badge record associated with that badge" do
      described_class.grant(badge, user)
      described_class.revoke_all(badge)

      expect(UserBadge.exists?(badge: badge, user: user)).to eq(false)
    end

    it "removes titles" do
      another_title = "another title"
      described_class.grant(badge, user)
      user.update!(title: badge.name)
      user2 = Fabricate(:user, title: another_title)

      described_class.revoke_all(badge)

      expect(user.reload.title).to be_nil
      expect(user2.reload.title).to eq(another_title)
    end

    it "removes custom badge titles" do
      custom_badge_title = "this is a badge title"
      I18n.backend.store_translations(
        :en,
        { badges: { Badge.i18n_name(badge.name) => { name: "Badge 0" } } },
      )
      TranslationOverride.create!(
        translation_key: badge.translation_key,
        value: custom_badge_title,
        locale: "en",
      )
      described_class.grant(badge, user)
      user.update!(title: custom_badge_title)

      described_class.revoke_all(badge)

      expect(user.reload.title).to be_nil
    end
  end

  describe "update_badges" do
    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:liker) { Fabricate(:user, refresh_auto_groups: true) }

    it "grants autobiographer" do
      user.user_profile.bio_raw = "THIS IS MY bio it a long bio I like my bio"
      user.uploaded_avatar_id = 10
      user.user_profile.save
      user.save

      BadgeGranter.process_queue!
      expect(UserBadge.where(user_id: user.id, badge_id: Badge::Autobiographer).count).to eq(1)
    end

    it "grants read guidelines" do
      user.user_stat.read_faq = Time.now
      user.user_stat.save

      BadgeGranter.process_queue!
      expect(UserBadge.where(user_id: user.id, badge_id: Badge::ReadGuidelines).count).to eq(1)
    end

    it "grants first link" do
      post = create_post
      post2 = create_post(raw: "#{Discourse.base_url}/t/slug/#{post.topic_id}")

      BadgeGranter.process_queue!
      expect(UserBadge.where(user_id: post2.user.id, badge_id: Badge::FirstLink).count).to eq(1)
    end

    it "grants first edit" do
      SiteSetting.editing_grace_period = 0
      post = create_post
      user = post.user

      expect(UserBadge.where(user_id: user.id, badge_id: Badge::Editor).count).to eq(0)

      PostRevisor.new(post).revise!(user, raw: "This is my new test 1235 123")
      BadgeGranter.process_queue!

      expect(UserBadge.where(user_id: user.id, badge_id: Badge::Editor).count).to eq(1)
    end

    it "grants and revokes trust level badges" do
      user.change_trust_level!(TrustLevel[4])
      BadgeGranter.process_queue!
      expect(UserBadge.where(user_id: user.id, badge_id: Badge.trust_level_badge_ids).count).to eq(
        4,
      )

      user.change_trust_level!(TrustLevel[1])
      BadgeGranter.backfill(Badge.find(1))
      BadgeGranter.backfill(Badge.find(2))
      expect(UserBadge.where(user_id: user.id, badge_id: 1).first).not_to eq(nil)
      expect(UserBadge.where(user_id: user.id, badge_id: 2).first).to eq(nil)
    end

    it "grants system like badges" do
      post = create_post(user: user)
      # Welcome badge
      action = PostActionCreator.like(liker, post).post_action
      BadgeGranter.process_queue!
      expect(UserBadge.find_by(user_id: user.id, badge_id: 5)).not_to eq(nil)

      post = create_post(topic: post.topic, user: user)
      action = PostActionCreator.like(liker, post).post_action

      # Nice post badge
      post.update like_count: 10

      BadgeGranter.queue_badge_grant(Badge::Trigger::PostAction, post_action: action)
      BadgeGranter.process_queue!

      expect(UserBadge.find_by(user_id: user.id, badge_id: Badge::NicePost)).not_to eq(nil)
      expect(UserBadge.where(user_id: user.id, badge_id: Badge::NicePost).count).to eq(1)

      # Good post badge
      post.update like_count: 25
      BadgeGranter.queue_badge_grant(Badge::Trigger::PostAction, post_action: action)
      BadgeGranter.process_queue!
      expect(UserBadge.find_by(user_id: user.id, badge_id: Badge::GoodPost)).not_to eq(nil)

      # Great post badge
      post.update like_count: 50
      BadgeGranter.queue_badge_grant(Badge::Trigger::PostAction, post_action: action)
      BadgeGranter.process_queue!
      expect(UserBadge.find_by(user_id: user.id, badge_id: Badge::GreatPost)).not_to eq(nil)

      # Revoke badges on unlike
      post.update like_count: 49
      BadgeGranter.backfill(Badge.find(Badge::GreatPost))
      expect(UserBadge.find_by(user_id: user.id, badge_id: Badge::GreatPost)).to eq(nil)
    end

    it "triggers the 'user_badge_granted' DiscourseEvent per badge when badges are backfilled" do
      post = create_post(user: user)
      action = PostActionCreator.like(liker, post).post_action

      events = DiscourseEvent.track_events(:user_badge_granted) { BadgeGranter.process_queue! }

      expect(events.length).to eq(2)
      expect(events[0][:params]).to eq([Badge::FirstLike, liker.id])
      expect(events[1][:params]).to eq([Badge::Welcome, user.id])
    end
  end

  describe "notification locales" do
    it "is using default locales when user locales are not set" do
      SiteSetting.allow_user_locale = true
      expect(BadgeGranter.notification_locale("")).to eq(SiteSetting.default_locale)
    end

    it "is using default locales when user locales are set but is not allowed" do
      SiteSetting.allow_user_locale = false
      expect(BadgeGranter.notification_locale("pl_PL")).to eq(SiteSetting.default_locale)
    end

    it "is using user locales when set and allowed" do
      SiteSetting.allow_user_locale = true
      expect(BadgeGranter.notification_locale("pl_PL")).to eq("pl_PL")
    end
  end

  describe ".mass_grant" do
    it "raises an error if the count argument is less than 1" do
      expect do BadgeGranter.mass_grant(badge, user, count: 0) end.to raise_error(
        ArgumentError,
        "count can't be less than 1",
      )
    end

    it "grants the badge to the user as many times as the count argument" do
      BadgeGranter.mass_grant(badge, user, count: 10)
      sequence = UserBadge.where(badge: badge, user: user).pluck(:seq).sort
      expect(sequence).to eq((0...10).to_a)

      BadgeGranter.mass_grant(badge, user, count: 10)
      sequence = UserBadge.where(badge: badge, user: user).pluck(:seq).sort
      expect(sequence).to eq((0...20).to_a)
    end
  end

  describe ".enqueue_mass_grant_for_users" do
    before { Jobs.run_immediately! }

    it "returns a list of the entries that could not be matched to any users" do
      results =
        BadgeGranter.enqueue_mass_grant_for_users(
          badge,
          emails: ["fakeemail@discourse.invalid", user.email],
          usernames: [user.username, "fakeusername"],
        )
      expect(results[:unmatched_entries]).to contain_exactly(
        "fakeemail@discourse.invalid",
        "fakeusername",
      )
      expect(results[:matched_users_count]).to eq(1)
      expect(results[:unmatched_entries_count]).to eq(2)
    end

    context "when ensure_users_have_badge_once is true" do
      it "ensures each user has the badge at least once and does not grant the badge multiple times to one user" do
        BadgeGranter.grant(badge, user)
        user_without_badge = Fabricate(:user)

        Notification.destroy_all
        results =
          BadgeGranter.enqueue_mass_grant_for_users(
            badge,
            usernames: [
              user.username,
              user.username,
              user_without_badge.username,
              user_without_badge.username,
            ],
            ensure_users_have_badge_once: true,
          )
        expect(results[:unmatched_entries]).to eq([])
        expect(results[:matched_users_count]).to eq(2)
        expect(results[:unmatched_entries_count]).to eq(0)

        sequence = UserBadge.where(user: user, badge: badge).pluck(:seq)
        expect(sequence).to contain_exactly(0)
        # no new badge/notification because user already had the badge
        # before enqueue_mass_grant_for_users was called
        expect(user.reload.notifications.size).to eq(0)

        sequence = UserBadge.where(user: user_without_badge, badge: badge)
        expect(sequence.pluck(:seq)).to contain_exactly(0)
        notifications = user_without_badge.reload.notifications
        expect(notifications.size).to eq(1)
        expect(sequence.first.notification_id).to eq(notifications.first.id)
        expect(notifications.first.notification_type).to eq(Notification.types[:granted_badge])
      end
    end

    context "when ensure_users_have_badge_once is false" do
      it "grants the badge to the users as many times as they appear in the emails and usernames arguments" do
        badge.update!(multiple_grant: true)
        user_without_badge = Fabricate(:user)
        user_with_badge = Fabricate(:user).tap { |u| BadgeGranter.grant(badge, u) }

        Notification.destroy_all
        emails = [user_with_badge.email.titlecase, user_without_badge.email.titlecase] * 20
        usernames = [user_with_badge.username.titlecase, user_without_badge.username.titlecase] * 20

        results =
          BadgeGranter.enqueue_mass_grant_for_users(
            badge,
            emails: emails,
            usernames: usernames,
            ensure_users_have_badge_once: false,
          )
        expect(results[:unmatched_entries]).to eq([])
        expect(results[:matched_users_count]).to eq(2)
        expect(results[:unmatched_entries_count]).to eq(0)

        sequence = UserBadge.where(user: user_with_badge, badge: badge).pluck(:seq)
        expect(sequence.size).to eq(40 + 1)
        expect(sequence.sort).to eq((0...(40 + 1)).to_a)
        sequence = UserBadge.where(user: user_without_badge, badge: badge).pluck(:seq)
        expect(sequence.size).to eq(40)
        expect(sequence.sort).to eq((0...40).to_a)

        # each user gets 1 notification no matter how many times
        # they're repeated in the file.
        [user_without_badge, user_with_badge].each do |u|
          notifications = u.reload.notifications
          expect(notifications.size).to eq(1)
          expect(notifications.map(&:notification_type).uniq).to contain_exactly(
            Notification.types[:granted_badge],
          )
        end
      end
    end
  end
end
