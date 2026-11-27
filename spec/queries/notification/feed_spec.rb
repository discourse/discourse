# frozen_string_literal: true

RSpec.describe Notification::Feed do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:group)

  def notify(type, topic: nil, data: {})
    Fabricate(
      :notification,
      user:,
      topic:,
      notification_type: Notification.types[type],
      data: data.to_json,
    )
  end

  describe "#types" do
    before do
      notify(:liked, topic: Fabricate(:topic)).update!(read: true)
      notify(:replied, topic: Fabricate(:topic, category: Fabricate(:private_category, group:)))
      notify(:edited, topic: Fabricate(:topic))
      notify(:edited, topic: Fabricate(:topic))
    end

    it "lists the types of visible notifications, read or unread" do
      expect(described_class.new(user).types).to contain_exactly(
        Notification.types[:edited],
        Notification.types[:liked],
      )
    end

    it "lists the same types when there are more notifications than it counts" do
      stub_const(described_class, :MAX_COUNTED, 1) do
        expect(described_class.new(user).types).to contain_exactly(
          Notification.types[:edited],
          Notification.types[:liked],
        )
      end
    end
  end

  describe "#notifications" do
    it "hides a reviewable mention once its reviewable is no longer viewable" do
      moderator = Fabricate(:moderator)
      reviewable = Fabricate(:reviewable_flagged_post)
      mention =
        Fabricate(
          :notification,
          user: moderator,
          notification_type: Notification.types[:mentioned],
          data: { reviewable_id: reviewable.id }.to_json,
        )
      regular =
        Fabricate(:notification, user: moderator, notification_type: Notification.types[:mentioned])

      expect(described_class.new(moderator).notifications).to contain_exactly(mention, regular)

      reviewable.update!(reviewable_by_moderator: false)

      expect(described_class.new(moderator.reload).notifications).to contain_exactly(regular)

      reviewable.destroy!

      expect(described_class.new(moderator.reload).notifications).to contain_exactly(regular)
    end

    it "hides a reviewable mention after category moderation membership is revoked" do
      SiteSetting.enable_category_group_moderation = true
      reviewable = Fabricate(:reviewable_flagged_post)
      reviewable.update!(category: reviewable.topic.category)
      Fabricate(:category_moderation_group, category: reviewable.category, group:)
      group.add(user)
      mention = notify(:mentioned, data: { reviewable_id: reviewable.id })

      expect(described_class.new(user.reload).notifications).to contain_exactly(mention)

      group.remove(user)

      expect(described_class.new(user.reload).notifications).to be_empty
    end

    it "hides badge notifications for disabled and missing badges" do
      enabled = notify(:granted_badge, data: { badge_id: Fabricate(:badge).id })
      notify(:granted_badge, data: { badge_id: Fabricate(:badge, enabled: false).id })
      notify(:granted_badge, data: { badge_id: Badge.maximum(:id) + 1 })

      expect(described_class.new(user).notifications).to contain_exactly(enabled)
    end

    it "hides a bookmark reminder that neither its topic nor its bookmarkable can vouch for" do
      register_test_bookmarkable
      UserTestBookmarkable.stubs(:visible_scope).returns(User.where(id: admin.id))
      on_topic = notify(:bookmark_reminder, topic: Fabricate(:topic))
      vouched =
        notify(:bookmark_reminder, data: { bookmarkable_type: "User", bookmarkable_id: admin.id })
      notify(:bookmark_reminder, data: { bookmarkable_type: "User", bookmarkable_id: user.id })
      notify(:bookmark_reminder, data: { bookmarkable_type: "Unknown", bookmarkable_id: 1 })
      notify(:bookmark_reminder, data: { bookmarkable_type: "Post", bookmarkable_id: 1 })
      notify(:bookmark_reminder)

      expect(described_class.new(user).notifications).to contain_exactly(on_topic, vouched)
    ensure
      DiscoursePluginRegistry.reset_register!(:bookmarkables)
    end

    it "shows a group inbox summary to admins, and to members only while they may use personal messages" do
      group.add(user)
      data = { group_id: group.id }
      for_admin =
        Fabricate(
          :notification,
          user: admin,
          notification_type: Notification.types[:group_message_summary],
          data: data.to_json,
        )
      for_member = notify(:group_message_summary, data:)

      expect(described_class.new(admin).notifications).to contain_exactly(for_admin)
      expect(described_class.new(user).notifications).to contain_exactly(for_member)

      SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:staff]

      expect(described_class.new(user.reload).notifications).to be_empty
    end

    it "only returns notifications both the owner and the viewer can see" do
      SiteSetting.suppress_secured_categories_from_admin = true
      group.add(user)
      admin_group = Fabricate(:group)
      admin_group.add(admin)
      owner_only =
        notify(:edited, topic: Fabricate(:topic, category: Fabricate(:private_category, group:)))
      notify(
        :edited,
        topic: Fabricate(:topic, category: Fabricate(:private_category, group: admin_group)),
      )
      shared = notify(:edited, topic: Fabricate(:topic))

      expect(described_class.new(user).notifications).to contain_exactly(owner_only, shared)
      expect(described_class.new(user, viewer: admin.guardian).notifications).to contain_exactly(
        shared,
      )
    end
  end

  describe "#counts" do
    fab!(:message) { Fabricate(:private_message_topic, user: admin, recipient: user) }

    it "counts visible unread notifications by type, priority and whether they were seen" do
      seen = notify(:edited, topic: Fabricate(:topic))
      notify(:edited, topic: Fabricate(:topic))
      notify(:private_message, topic: message)
      notify(:liked, topic: Fabricate(:topic)).update!(read: true)
      notify(:edited, topic: Fabricate(:topic, category: Fabricate(:private_category, group:)))
      user.update!(seen_notification_id: seen.id)

      counts = described_class.new(user).counts

      expect(counts.grouped).to eq(
        Notification.types[:edited] => 2,
        Notification.types[:private_message] => 1,
      )
      expect(counts.high_priority).to eq(1)
      expect(counts.unseen).to eq(2)
      expect(counts.unseen_low_priority).to eq(1)
      expect(counts.unseen_of_type(Notification.types[:private_message])).to eq(1)
    end

    it "keeps counting regular notifications when high priority ones reach the limit" do
      2.times { notify(:private_message, topic: message) }
      notify(:edited, topic: Fabricate(:topic))

      stub_const(described_class, :MAX_COUNTED, 2) do
        counts = described_class.new(user).counts

        expect(counts.high_priority).to eq(2)
        expect(counts.unseen_low_priority).to eq(1)
      end
    end

    it "hides a notification whose data holds an id too large to look up" do
      Fabricate(
        :notification,
        user:,
        notification_type: Notification.types[:granted_badge],
        data: { badge_id: "99999999999999999999" }.to_json,
      )

      expect(described_class.new(user).counts.grouped).to be_empty
    end

    context "with a plugin rule" do
      let(:plugin) { Plugin::Instance.new }

      before { notify(:edited, topic: Fabricate(:topic)) }

      after do
        DiscoursePluginRegistry.notification_visibility_rules.reject! do |registered|
          registered[:plugin] == plugin
        end
      end

      it "hides the types of a rule that returns nothing" do
        plugin.register_notification_visibility_rule(types: [:edited]) { nil }

        expect(described_class.new(user).counts.grouped).to be_empty
      end

      it "rejects a rule for an unknown type or for no type" do
        expect {
          plugin.register_notification_visibility_rule(types: [:unknown]) { "TRUE" }
        }.to raise_error(KeyError)
        expect {
          plugin.register_notification_visibility_rule(types: []) { "TRUE" }
        }.to raise_error(ArgumentError)
      end

      it "applies the rule to its types only" do
        plugin.register_notification_visibility_rule(types: [:liked]) { "FALSE" }
        notify(:liked, topic: Fabricate(:topic))

        expect(described_class.new(user).counts.grouped).to eq(Notification.types[:edited] => 1)
      end

      it "hides the types of a disabled plugin" do
        plugin.register_notification_visibility_rule(types: [:edited]) { "TRUE" }
        plugin.stubs(:enabled?).returns(false)

        expect(described_class.new(user).counts.grouped).to be_empty
      end
    end

    it "counts the newest visible notifications past the unread limit" do
      notify(:edited, topic: Fabricate(:topic))
      notify(:liked, topic: Fabricate(:topic))
      notify(:edited, topic: Fabricate(:topic, category: Fabricate(:private_category, group:)))
      notify(:private_message, topic: message)

      stub_const(described_class, :MAX_COUNTED, 1) do
        expect(described_class.new(user).counts.grouped).to eq(
          Notification.types[:liked] => 1,
          Notification.types[:private_message] => 1,
        )
      end
    end

    it "counts high priority notifications before newer regular ones past the unread limit" do
      notify(:private_message, topic: message)
      notify(:edited, topic: Fabricate(:topic))
      notify(:edited, topic: Fabricate(:topic))

      stub_const(described_class, :MAX_COUNTED, 2) do
        expect(described_class.new(user).counts.high_priority).to eq(1)
      end
    end
  end

  describe "#page" do
    it "returns the notifications older than the cursor, newest first" do
      created_at = 1.hour.ago
      older = Fabricate(:notification, user:, created_at: 2.hours.ago)
      first_tied = Fabricate(:notification, user:, created_at:)
      second_tied = Fabricate(:notification, user:, created_at:)
      newer = Fabricate(:notification, user:, created_at: 1.minute.ago)

      feed = described_class.new(user)

      expect(feed.page(limit: 10).notifications.map(&:id)).to eq(
        [newer.id, second_tied.id, first_tied.id, older.id],
      )
      expect(
        feed.page(limit: 10, before: [created_at, second_tied.id]).notifications.map(&:id),
      ).to eq([first_tied.id, older.id])
    end

    it "gives the cursor of its last notification only while older ones exist" do
      older = Fabricate(:notification, user:, created_at: 2.hours.ago)
      newer = Fabricate(:notification, user:, created_at: 1.hour.ago)

      feed = described_class.new(user)
      first_page = feed.page(limit: 1)

      expect(first_page.notifications).to contain_exactly(newer)
      expect(first_page.cursor).to eq([newer.reload.created_at, newer.id])
      expect(feed.page(limit: 1, before: first_page.cursor).notifications).to contain_exactly(older)
      expect(feed.page(limit: 1, before: first_page.cursor).cursor).to be_nil
      expect(feed.page(limit: 0).cursor).to be_nil
    end

    it "filters by read state" do
      read = Fabricate(:notification, user:, read: true)
      unread = Fabricate(:notification, user:, read: false)

      feed = described_class.new(user)

      expect(feed.page(limit: 10, state: :read).notifications).to contain_exactly(read)
      expect(feed.page(limit: 10, state: :unread).notifications).to contain_exactly(unread)
    end
  end

  describe "#menu" do
    def create(**opts)
      Fabricate(:notification, user:, **opts)
    end

    fab!(:unread_high_priority_1) do
      create(high_priority: true, read: false, created_at: 8.minutes.ago)
    end
    fab!(:read_high_priority_1) do
      create(high_priority: true, read: true, created_at: 7.minutes.ago)
    end
    fab!(:unread_regular_1) { create(high_priority: false, read: false, created_at: 6.minutes.ago) }
    fab!(:read_regular_1) { create(high_priority: false, read: true, created_at: 5.minutes.ago) }
    fab!(:unread_like) do
      create(
        high_priority: false,
        read: false,
        created_at: 130.seconds.ago,
        notification_type: Notification.types[:liked],
      )
    end

    fab!(:unread_high_priority_2) do
      create(high_priority: true, read: false, created_at: 1.minute.ago)
    end
    fab!(:read_high_priority_2) do
      create(high_priority: true, read: true, created_at: 2.minutes.ago)
    end
    fab!(:unread_regular_2) { create(high_priority: false, read: false, created_at: 3.minutes.ago) }
    fab!(:read_regular_2) { create(high_priority: false, read: true, created_at: 4.minutes.ago) }

    it "puts unread high_priority on top followed by unread normal notifications and then everything else in reverse chronological order" do
      expect(described_class.new(user).menu(limit: 30).map(&:id)).to eq(
        [
          unread_high_priority_2,
          unread_high_priority_1,
          unread_regular_2,
          unread_regular_1,
          read_high_priority_2,
          unread_like,
          read_regular_2,
          read_regular_1,
          read_high_priority_1,
        ].map(&:id),
      )
    end

    it "doesn't include notifications from other users" do
      another_user_notification = create(high_priority: true, read: false, user: Fabricate(:user))
      expect(described_class.new(user).menu(limit: 30).map(&:id)).to contain_exactly(
        *[
          unread_high_priority_2,
          unread_high_priority_1,
          unread_regular_2,
          unread_regular_1,
          read_high_priority_2,
          unread_like,
          read_regular_2,
          read_regular_1,
          read_high_priority_1,
        ].map(&:id),
      )
      expect(
        described_class.new(another_user_notification.user).menu(limit: 30).map(&:id),
      ).to contain_exactly(another_user_notification.id)
    end

    it "respects the count param" do
      expect(described_class.new(user).menu(limit: 1).map(&:id)).to eq(
        [unread_high_priority_2].map(&:id),
      )

      expect(described_class.new(user).menu(limit: 3).map(&:id)).to eq(
        [unread_high_priority_2, unread_high_priority_1, unread_regular_2].map(&:id),
      )
    end

    it "can filter the list by specific types" do
      unread_regular_1.update!(notification_type: Notification.types[:liked])
      read_regular_2.update!(notification_type: Notification.types[:liked_consolidated])
      expect(
        described_class
          .new(user)
          .menu(
            limit: 30,
            types: [Notification.types[:liked], Notification.types[:liked_consolidated]],
          )
          .map(&:id),
      ).to eq([unread_like, unread_regular_1, read_regular_2].map(&:id))
    end

    it "excludes like notifications when the user doesn't want like notifications" do
      user.user_option.update!(
        like_notification_frequency: UserOption.like_notification_frequency_type[:never],
      )
      unread_regular_1.update!(notification_type: Notification.types[:liked])

      expect(
        described_class.new(user).menu(limit: 30, types: [Notification.types[:liked]]).map(&:id),
      ).to be_empty
      expect(described_class.new(user).menu(limit: 30).map(&:id)).not_to include(
        unread_like.id,
        unread_regular_1.id,
      )
    end
  end
end
