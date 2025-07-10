# frozen_string_literal: true

require "rails_helper"
require_relative "../fabricators/reaction_fabricator.rb"
require_relative "../fabricators/reaction_user_fabricator.rb"

describe DiscourseReactions::ReactionNotification do
  before do
    SiteSetting.discourse_reactions_enabled = true
    PostActionNotifier.enable
  end

  fab!(:post_1) { Fabricate(:post) }
  fab!(:thumbsup) { Fabricate(:reaction, post: post_1, reaction_value: "thumbsup") }
  fab!(:user_1) { Fabricate(:user, name: "Bruce Wayne Jr.") }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:user_3) { Fabricate(:user, name: "Bruce Wayne Sr.") }
  fab!(:reaction_user1) { Fabricate(:reaction_user, reaction: thumbsup, user: user_1) }
  fab!(:like_reaction) { Fabricate(:reaction, post: post_1, reaction_value: "heart") }

  it "does not create notification when user is muted" do
    MutedUser.create!(user_id: post_1.user.id, muted_user_id: user_1.id)
    expect { described_class.new(thumbsup, user_1).create }.not_to change { Notification.count }
  end

  it "does not create notification when topic is muted" do
    TopicUser.create!(
      topic: post_1.topic,
      user: post_1.user,
      notification_level: TopicUser.notification_levels[:muted],
    )
    MutedUser.create!(user_id: post_1.user.id, muted_user_id: user_1.id)
    described_class.new(thumbsup, user_1).create
    expect { described_class.new(thumbsup, user_1).create }.not_to change { Notification.count }
  end

  it "does not create notification when notification setting is never" do
    post_1.user.user_option.update!(
      like_notification_frequency: UserOption.like_notification_frequency_type[:never],
    )
    MutedUser.create!(user_id: post_1.user.id, muted_user_id: user_1.id)
    expect { described_class.new(thumbsup, user_1).create }.not_to change { Notification.count }
  end

  it "correctly creates notification when notification setting is first time and daily" do
    post_1.user.user_option.update!(
      like_notification_frequency:
        UserOption.like_notification_frequency_type[:first_time_and_daily],
    )

    expect { described_class.new(thumbsup, user_1).create }.to change { Notification.count }.by(1)
    expect(Notification.last.user_id).to eq(post_1.user.id)
    expect(Notification.last.notification_type).to eq(Notification.types[:reaction])
    expect(JSON.parse(Notification.last.data)["original_username"]).to eq(user_1.username)

    user_2 = Fabricate(:user)
    Fabricate(:reaction_user, reaction: thumbsup, user: user_2)
    expect { described_class.new(thumbsup, user_2).create }.not_to change { Notification.count }

    freeze_time(Time.zone.now + 1.day)

    cry = Fabricate(:reaction, post: post_1, reaction_value: "cry")
    Fabricate(:reaction_user, reaction: cry, user: user_2)
    expect { described_class.new(cry, user_2).create }.to change { Notification.count }.by(1)
  end

  it "deletes notification when all reactions are removed" do
    expect { described_class.new(thumbsup, user_1).create }.to change { Notification.count }.by(1)

    cry = Fabricate(:reaction, post: post_1, reaction_value: "cry")
    Fabricate(:reaction_user, reaction: cry, user: user_1)
    expect { described_class.new(cry, user_1).create }.not_to change { Notification.count }

    user_2 = Fabricate(:user)
    Fabricate(:reaction_user, reaction: cry, user: user_2)
    expect { described_class.new(cry, user_1).create }.not_to change { Notification.count }
    expect(JSON.parse(Notification.last.data)["display_username"]).to eq(user_1.username)

    DiscourseReactions::ReactionUser.find_by(reaction: cry, user: user_1).destroy
    DiscourseReactions::ReactionUser.find_by(reaction: thumbsup, user: user_1).destroy
    expect do
      described_class.new(cry, user_1).delete
      described_class.new(thumbsup, user_1).delete
    end.not_to change { Notification.count }
    expect(JSON.parse(Notification.last.data)["display_username"]).to eq(user_2.username)
    expect(Notification.last.notification_type).to eq(Notification.types[:reaction])

    DiscourseReactions::ReactionUser.find_by(reaction: cry, user: user_2).destroy
    expect { described_class.new(cry, user_2).delete }.to change { Notification.count }.by(-1)
  end

  it "displays the full name" do
    cry_p1 = Fabricate(:reaction, post: post_1, reaction_value: "cry")

    described_class.new(cry_p1, user_2).create

    expect(
      Notification.where(notification_type: Notification.types[:reaction], user: post_1.user).count,
    ).to eq(1)

    notification = Notification.where(notification_type: Notification.types[:reaction]).last
    expect(notification.data_hash[:display_name]).to eq(user_2.name)
  end

  it "adds the heart icon when the remaining notification is a like" do
    Fabricate(:reaction_user, reaction: like_reaction, user: user_2)
    described_class.new(like_reaction, user_2).create

    DiscourseReactions::ReactionUser.find_by(reaction: thumbsup, user: user_1).destroy!
    described_class.new(thumbsup, user_1).delete

    remaining_notification =
      Notification.where(notification_type: Notification.types[:reaction]).last

    expect(remaining_notification.data_hash[:reaction_icon]).to eq(like_reaction.reaction_value)
  end

  it "doesn't add the heart icon when not all remaining notifications are likes" do
    Fabricate(:reaction_user, reaction: like_reaction, user: user_2)
    described_class.new(like_reaction, user_2).create

    cry = Fabricate(:reaction, post: post_1, reaction_value: "cry")
    Fabricate(:reaction_user, reaction: cry, user: user_3)
    described_class.new(cry, user_3).create

    DiscourseReactions::ReactionUser.find_by(reaction: thumbsup, user: user_1).destroy!
    described_class.new(thumbsup, user_1).delete

    remaining_notification =
      Notification.where(notification_type: Notification.types[:reaction]).last

    expect(remaining_notification.data_hash[:reaction_icon]).to be_nil
  end

  describe "consolidating reaction notifications" do
    fab!(:post_2) { Fabricate(:post, user: post_1.user) }
    let!(:cry_p1) { Fabricate(:reaction, post: post_1, reaction_value: "cry") }
    let!(:cry_p2) { Fabricate(:reaction, post: post_2, reaction_value: "cry") }

    describe "multiple reactions from the same user" do
      before { SiteSetting.notification_consolidation_threshold = 1 }

      it "consolidates notifications from the same user" do
        described_class.new(cry_p1, user_2).create
        described_class.new(cry_p2, user_2).create

        expect(
          Notification.where(
            notification_type: Notification.types[:reaction],
            user: post_1.user,
          ).count,
        ).to eq(1)
        consolidated_notification =
          Notification.where(notification_type: Notification.types[:reaction]).last

        expect(consolidated_notification.data_hash[:consolidated]).to eq(true)
        expect(consolidated_notification.data_hash[:username]).to eq(user_2.username)
      end

      it "doesn't update a consolidated notification when a different user reacts to a post" do
        described_class.new(cry_p1, user_2).create
        described_class.new(cry_p2, user_2).create
        described_class.new(cry_p2, user_3).create

        expect(
          Notification.where(
            notification_type: Notification.types[:reaction],
            user: post_1.user,
          ).count,
        ).to eq(2)
        consolidated_notification =
          Notification.where(notification_type: Notification.types[:reaction]).last

        expect(consolidated_notification.data_hash[:consolidated]).to be_nil
        expect(consolidated_notification.data_hash[:display_username]).to eq(user_3.username)
      end

      it "keeps the reaction icon when consolidating multiple likes from the same user" do
        like_reaction_p2 = Fabricate(:reaction, post: post_2, reaction_value: "heart")

        described_class.new(like_reaction, user_2).create
        described_class.new(like_reaction_p2, user_2).create

        consolidated_notification =
          Notification.where(notification_type: Notification.types[:reaction]).last

        expect(consolidated_notification.data_hash[:consolidated]).to eq(true)
        expect(consolidated_notification.data_hash[:reaction_icon]).to eq(
          like_reaction.reaction_value,
        )
      end

      it "doesn't add the reaction icon when consolidating a non-like and a like notification" do
        described_class.new(cry_p2, user_2).create
        described_class.new(like_reaction, user_2).create

        consolidated_notification =
          Notification.where(notification_type: Notification.types[:reaction]).last

        expect(consolidated_notification.data_hash[:reaction_icon]).to be_nil
      end

      it "removes the reaction icon when updating a like consolidated notification with a different reactions" do
        like_reaction_p2 = Fabricate(:reaction, post: post_2, reaction_value: "heart")
        post_3 = Fabricate(:post, user: post_1.user)
        cry_p3 = Fabricate(:reaction, post: post_3, reaction_value: "cry")

        described_class.new(like_reaction, user_2).create
        described_class.new(like_reaction_p2, user_2).create
        described_class.new(cry_p3, user_2).create

        consolidated_notification =
          Notification.where(notification_type: Notification.types[:reaction]).last

        expect(consolidated_notification.data_hash[:reaction_icon]).to be_nil
      end
    end

    describe "multiple users reacting to the same post" do
      before do
        post_1.user.user_option.update!(
          like_notification_frequency: UserOption.like_notification_frequency_type[:always],
        )
      end

      it "keeps one notification pointing to the two last users that reacted to a post" do
        described_class.new(cry_p1, user_2).create
        described_class.new(thumbsup, user_3).create

        expect(
          Notification.where(
            notification_type: Notification.types[:reaction],
            user: post_1.user,
          ).count,
        ).to eq(1)

        consolidated_notification =
          Notification.where(notification_type: Notification.types[:reaction]).last

        expect(consolidated_notification.data_hash[:display_username]).to eq(user_3.username)
        expect(consolidated_notification.data_hash[:username2]).to eq(user_2.username)
        expect(consolidated_notification.data_hash[:display_name]).to eq(user_3.name)
        expect(consolidated_notification.data_hash[:name2]).to eq(user_2.name)
      end

      it "creates a new notification if the last one was created more than one day ago" do
        first_notification = described_class.new(cry_p1, user_2).create
        first_notification.update!(created_at: 2.days.ago)

        described_class.new(thumbsup, user_3).create

        expect(
          Notification.where(
            notification_type: Notification.types[:reaction],
            user: post_1.user,
          ).count,
        ).to eq(2)
      end

      it "keeps the icon of the last notification" do
        described_class.new(thumbsup, user_3).create
        described_class.new(like_reaction, user_2).create

        consolidated_notification =
          Notification.where(notification_type: Notification.types[:reaction]).last

        expect(consolidated_notification.data_hash[:reaction_icon]).to eq(
          like_reaction.reaction_value,
        )
      end
    end
  end

  describe "stores the icon in the notification payload" do
    it "stores the heart icon for like reactions" do
      described_class.new(like_reaction, user_2).create
      notification =
        Notification.where(user: post_1.user, notification_type: Notification.types[:reaction]).last

      expect(notification.data_hash[:reaction_icon]).to eq(like_reaction.reaction_value)
    end
  end
end
