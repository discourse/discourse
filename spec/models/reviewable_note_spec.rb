# frozen_string_literal: true

RSpec.describe ReviewableNote do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:reviewable, :reviewable_flagged_post)

  describe "associations" do
    it { is_expected.to belong_to(:reviewable) }
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    subject { build(:reviewable_note, reviewable: reviewable, user: admin) }

    it { is_expected.to validate_presence_of(:content) }

    it do
      is_expected.to validate_length_of(:content).is_at_least(1).is_at_most(
        ReviewableNote::MAX_CONTENT_LENGTH,
      )
    end

    it { is_expected.to validate_presence_of(:reviewable_id) }
    it { is_expected.to validate_presence_of(:user_id) }

    context "when content is blank" do
      it "is invalid with empty content" do
        note = build(:reviewable_note, content: "", reviewable: reviewable, user: admin)
        expect(note).not_to be_valid
        expect(note.errors[:content]).to include("can't be blank")
      end

      it "is invalid with whitespace-only content" do
        note = build(:reviewable_note, content: "   ", reviewable: reviewable, user: admin)
        expect(note).not_to be_valid
        expect(note.errors[:content]).to include("can't be blank")
      end
    end

    context "when content is too long" do
      it "is invalid with content over #{ReviewableNote::MAX_CONTENT_LENGTH} characters" do
        long_content = "a" * (ReviewableNote::MAX_CONTENT_LENGTH + 1)
        note = build(:reviewable_note, content: long_content, reviewable: reviewable, user: admin)
        expect(note).not_to be_valid
        expect(note.errors[:content]).to include(
          "is too long (maximum is #{ReviewableNote::MAX_CONTENT_LENGTH} characters)",
        )
      end

      it "is valid with content at exactly #{ReviewableNote::MAX_CONTENT_LENGTH} characters" do
        max_content = "a" * ReviewableNote::MAX_CONTENT_LENGTH
        note = build(:reviewable_note, content: max_content, reviewable: reviewable, user: admin)
        expect(note).to be_valid
      end
    end
  end

  describe "scopes" do
    fab!(:old_note) do
      Fabricate(:reviewable_note, reviewable: reviewable, user: admin, created_at: 2.days.ago)
    end
    fab!(:new_note) do
      Fabricate(:reviewable_note, reviewable: reviewable, user: moderator, created_at: 1.day.ago)
    end

    describe ".ordered" do
      it "returns notes ordered by creation date ascending" do
        notes = ReviewableNote.ordered
        expect(notes.first).to eq(old_note)
        expect(notes.last).to eq(new_note)
      end
    end
  end

  describe "factory" do
    it "creates a valid reviewable note" do
      note = Fabricate(:reviewable_note, reviewable: reviewable, user: admin)
      expect(note).to be_valid
      expect(note.content).to be_present
      expect(note.reviewable).to eq(reviewable)
      expect(note.user).to eq(admin)
    end
  end

  describe ".create!" do
    before { SiteSetting.enable_mentions = true }

    it "notifies mentioned reviewers once and reports users who cannot see the reviewable" do
      other_admin = Fabricate(:admin)

      note =
        ReviewableNote.create!(
          reviewable: reviewable,
          user: admin,
          content:
            "@#{moderator.username.upcase} @#{moderator.username} @#{other_admin.username} @#{user.username} @#{admin.username}",
        )

      notifications = Notification.where(notification_type: Notification.types[:mentioned])
      expect(notifications.pluck(:user_id)).to contain_exactly(moderator.id, other_admin.id)
      expect(note.unnotified_usernames).to eq([user.username])
      expect(notifications.first.data_hash).to include(
        "reviewable_id" => reviewable.id,
        "reviewable_note_id" => note.id,
        "topic_title" => reviewable.topic.title,
        "display_username" => admin.username,
      )
      expect(notifications.first.topic_id).to be_nil
      expect(notifications.first.post_number).to be_nil
    end

    it "warns about a moderator who cannot see an admin-only reviewable" do
      reviewable.update!(reviewable_by_moderator: false)

      note =
        ReviewableNote.create!(
          reviewable: reviewable,
          user: admin,
          content: "@#{moderator.username}",
        )

      expect(
        moderator.notifications.where(notification_type: Notification.types[:mentioned]),
      ).to be_empty
      expect(note.unnotified_usernames).to eq([moderator.username])
    end

    it "notifies category moderators only about reviewables in their category" do
      SiteSetting.enable_category_group_moderation = true
      group = Fabricate(:group)
      group.add(user)
      category = reviewable.topic.category
      reviewable.update!(category: category)
      Fabricate(:category_moderation_group, category: category, group: group)
      other_reviewable = Fabricate(:reviewable_flagged_post, category: Fabricate(:category))

      visible_note =
        ReviewableNote.create!(reviewable: reviewable, user: admin, content: "@#{user.username}")
      hidden_note =
        ReviewableNote.create!(
          reviewable: other_reviewable,
          user: admin,
          content: "@#{user.username}",
        )

      notifications = user.notifications.where(notification_type: Notification.types[:mentioned])
      expect(notifications.size).to eq(1)
      expect(notifications.first.data_hash["reviewable_note_id"]).to eq(visible_note.id)
      expect(visible_note.unnotified_usernames).to be_empty
      expect(hidden_note.unnotified_usernames).to eq([user.username])
    end

    it "uses the submitted title for a queued new topic" do
      queued_topic = Fabricate(:reviewable_queued_post_topic)

      ReviewableNote.create!(
        reviewable: queued_topic,
        user: admin,
        content: "@#{moderator.username}",
      )

      notification =
        moderator.notifications.find_by!(notification_type: Notification.types[:mentioned])
      expect(notification.data_hash["topic_title"]).to eq(queued_topic.payload["title"])
    end

    it "uses a neutral title for reviewables without topic or title metadata" do
      reviewable.update!(topic: nil, target: nil)

      ReviewableNote.create!(reviewable: reviewable, user: admin, content: "@#{moderator.username}")

      notification =
        moderator.notifications.find_by!(notification_type: Notification.types[:mentioned])
      expect(notification.data_hash["topic_title"]).to eq(I18n.t("js.review.title"))
    end

    it "identifies deleted topics when the topic association is missing" do
      reviewable.update_columns(topic_id: -123)
      reviewable.reload

      ReviewableNote.create!(reviewable: reviewable, user: admin, content: "@#{moderator.username}")

      notification =
        moderator.notifications.find_by!(notification_type: Notification.types[:mentioned])
      expect(notification.data_hash["topic_title"]).to eq(I18n.t("js.review.topics.deleted"))
    end

    it "respects recipients muting or ignoring a non-staff author" do
      other_admin = Fabricate(:admin)
      Fabricate(:muted_user, user: moderator, muted_user: user)
      Fabricate(:ignored_user, user: other_admin, ignored_user: user)
      user.update!(trust_level: 1)

      note =
        ReviewableNote.create!(
          reviewable: reviewable,
          user: user,
          content: "@#{moderator.username} @#{other_admin.username}",
        )

      expect(Notification.where(notification_type: Notification.types[:mentioned])).to be_empty
      expect(note.unnotified_usernames).to be_empty
    end

    it "allows staff authors to notify recipients who muted them" do
      Fabricate(:muted_user, user: moderator, muted_user: admin)

      ReviewableNote.create!(reviewable: reviewable, user: admin, content: "@#{moderator.username}")

      expect(
        moderator.notifications.where(notification_type: Notification.types[:mentioned]).count,
      ).to eq(1)
    end

    it "skips bot recipients" do
      note =
        ReviewableNote.create!(
          reviewable: reviewable,
          user: admin,
          content: "@#{Discourse.system_user.username}",
        )

      expect(Notification.where(notification_type: Notification.types[:mentioned])).to be_empty
      expect(note.unnotified_usernames).to be_empty
    end

    it "enforces the mention limit for non-staff authors before creating notifications" do
      user.update!(trust_level: 1)
      SiteSetting.max_mentions_per_post = 1
      note =
        ReviewableNote.new(
          reviewable: reviewable,
          user: user,
          content: "@#{moderator.username} @#{admin.username}",
        )

      expect(note.save).to eq(false)
      expect(note.errors[:base]).to eq([I18n.t("too_many_mentions", count: 1)])
      expect(Notification.where(notification_type: Notification.types[:mentioned])).to be_empty

      note.content = "@#{moderator.username} @#{moderator.username.upcase}"
      expect(note.save).to eq(true)
      expect(
        moderator.notifications.where(notification_type: Notification.types[:mentioned]).count,
      ).to eq(1)
    end

    it "applies the new-user mention limit and exempts staff" do
      user.update!(trust_level: 0)
      SiteSetting.newuser_max_mentions_per_post = 0
      note =
        ReviewableNote.new(reviewable: reviewable, user: user, content: "@#{moderator.username}")

      expect(note.save).to eq(false)
      expect(note.errors[:base]).to eq([I18n.t("no_mentions_allowed_newuser")])

      note.user = admin
      expect(note.save).to eq(true)
      expect(
        moderator.notifications.where(notification_type: Notification.types[:mentioned]).count,
      ).to eq(1)
    end

    it "uses the topic title for a queued reply" do
      queued_reply = Fabricate(:reviewable_queued_post)

      ReviewableNote.create!(
        reviewable: queued_reply,
        user: admin,
        content: "@#{moderator.username}",
      )

      notification =
        moderator.notifications.find_by!(notification_type: Notification.types[:mentioned])
      expect(notification.data_hash["topic_title"]).to eq(queued_reply.topic.title)
    end

    it "uses the username for a reviewable user" do
      reviewable_user = Fabricate(:reviewable_user)

      ReviewableNote.create!(
        reviewable: reviewable_user,
        user: admin,
        content: "@#{moderator.username}",
      )

      notification =
        moderator.notifications.find_by!(notification_type: Notification.types[:mentioned])
      expect(notification.data_hash["topic_title"]).to eq(reviewable_user.target.username)
    end

    it "warns about moderators who cannot access a private category" do
      group = Fabricate(:group)
      private_category = Fabricate(:private_category, group: group)
      reviewable.topic.update!(category: private_category)
      reviewable.update!(category: private_category)

      note =
        ReviewableNote.create!(
          reviewable: reviewable,
          user: admin,
          content: "@#{moderator.username}",
        )

      expect(
        moderator.notifications.where(notification_type: Notification.types[:mentioned]),
      ).to be_empty
      expect(note.unnotified_usernames).to eq([moderator.username])
    end

    it "ignores mentions inside code, quotes, and nonexistent usernames" do
      note =
        ReviewableNote.create!(
          reviewable: reviewable,
          user: admin,
          content:
            "`@#{moderator.username}`\n\n[quote]\n@#{user.username}\n[/quote]\n\n@nonexistent_reviewer",
        )

      expect(Notification.where(notification_type: Notification.types[:mentioned])).to be_empty
      expect(note.unnotified_usernames).to be_empty
    end

    it "respects disabled mentions" do
      SiteSetting.enable_mentions = false

      note =
        ReviewableNote.create!(
          reviewable: reviewable,
          user: admin,
          content: "@#{moderator.username}",
        )

      expect(Notification.where(notification_type: Notification.types[:mentioned])).to be_empty
      expect(note.unnotified_usernames).to be_empty
    end

    it "creates no notifications for an invalid note" do
      note =
        ReviewableNote.new(
          reviewable: reviewable,
          user: admin,
          content: "@#{moderator.username} " * 2000,
        )

      expect(note.save).to eq(false)
      expect(Notification.where(notification_type: Notification.types[:mentioned])).to be_empty
    end
  end
end
