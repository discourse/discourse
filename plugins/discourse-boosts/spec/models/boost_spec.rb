# frozen_string_literal: true

require "rails_helper"

describe DiscourseBoosts::Boost, type: :model do
  fab!(:post)
  fab!(:user)

  before { SiteSetting.discourse_boosts_enabled = true }

  describe "validations" do
    it { is_expected.to validate_length_of(:raw).is_at_most(1000) }

    it "requires raw" do
      boost = DiscourseBoosts::Boost.new(post: post, user: user, raw: "", cooked: "")
      expect(boost).not_to be_valid
    end

    it "does not allow duplicate boosts for the same post and user" do
      Fabricate(:boost, post: post, user: user)

      duplicate = DiscourseBoosts::Boost.new(post: post, user: user, raw: "🎉")

      duplicate.valid?

      expect(duplicate.errors[:post_id]).to include(I18n.t("errors.messages.taken"))
    end

    it "enforces max visible length of 16" do
      boost = DiscourseBoosts::Boost.new(post: post, user: user, raw: "a" * 17)
      expect(boost).not_to be_valid
    end

    it "counts emoji as 1 visible character" do
      boost =
        DiscourseBoosts::Boost.new(
          post: post,
          user: user,
          raw: ":smiling_face_with_heart_eyes:" * 5,
        )
      expect(boost).to be_valid
    end

    it "does not count invalid emoji codes as 1 character" do
      boost =
        DiscourseBoosts::Boost.new(post: post, user: user, raw: ":not_a_real_emoji_code_at_all:")
      expect(boost).not_to be_valid
    end

    it "allows up to 5 emoji" do
      boost = DiscourseBoosts::Boost.new(post: post, user: user, raw: ":blush:" * 5)
      expect(boost).to be_valid
    end

    it "rejects more than 5 emoji" do
      boost = DiscourseBoosts::Boost.new(post: post, user: user, raw: ":blush:" * 6)
      expect(boost).not_to be_valid
    end

    it "counts native Unicode emoji toward the emoji limit" do
      boost = DiscourseBoosts::Boost.new(post: post, user: user, raw: "😀😃😄😁😆😅")
      expect(boost).not_to be_valid
    end

    it "allows up to 5 native Unicode emoji" do
      boost = DiscourseBoosts::Boost.new(post: post, user: user, raw: "😀😃😄😁😆")
      expect(boost).to be_valid
    end

    it "counts mixed shortcode and Unicode emoji together" do
      boost = DiscourseBoosts::Boost.new(post: post, user: user, raw: ":blush::blush::blush:😀😃😄")
      expect(boost).not_to be_valid
    end

    it "counts native Unicode emoji as 1 visible character each" do
      boost = DiscourseBoosts::Boost.new(post: post, user: user, raw: "👨‍👩‍👧‍👦" * 5)
      expect(boost).to be_valid
    end

    it "counts skin-toned emoji shortcodes as 1 visible character" do
      boost = DiscourseBoosts::Boost.new(post: post, user: user, raw: ":thumbsup:t2:" * 5)
      expect(boost).to be_valid
    end

    it "counts skin-toned emoji shortcodes toward the emoji limit" do
      boost = DiscourseBoosts::Boost.new(post: post, user: user, raw: ":thumbsup:t2:" * 6)
      expect(boost).not_to be_valid
    end

    it "allows valid boost" do
      boost = DiscourseBoosts::Boost.new(post: post, user: user, raw: "🎉")
      expect(boost).to be_valid
    end
  end

  describe ".cook" do
    it "cooks emoji" do
      cooked = DiscourseBoosts::Boost.cook(":tada:")
      expect(cooked).to include("emoji")
    end

    it "does not render links" do
      cooked = DiscourseBoosts::Boost.cook("https://example.com")
      expect(cooked).not_to include("<a")
    end
  end

  describe "after_destroy" do
    fab!(:other_user, :user)

    it "deletes the boost notification for the destroying user" do
      boost = Fabricate(:boost, post: post, user: user)
      notification =
        Fabricate(
          :notification,
          user: post.user,
          topic: post.topic,
          post_number: post.post_number,
          notification_type: Notification.types[:boost],
          data: { display_username: user.username }.to_json,
        )

      expect { boost.destroy! }.to change {
        Notification.where(user: post.user, notification_type: Notification.types[:boost]).count
      }.by(-1)
      expect(Notification.exists?(notification.id)).to eq(false)
    end

    it "does not delete notifications from other boost users" do
      boost = Fabricate(:boost, post: post, user: user)
      other_notification =
        Fabricate(
          :notification,
          user: post.user,
          topic: post.topic,
          post_number: post.post_number,
          notification_type: Notification.types[:boost],
          data: { display_username: other_user.username }.to_json,
        )

      boost.destroy!

      expect(Notification.exists?(other_notification.id)).to eq(true)
    end

    it "converts consolidated 2-user notification to single-user when one user's boost is deleted" do
      other_boost = Fabricate(:boost, post: post, user: other_user)
      boost = Fabricate(:boost, post: Fabricate(:post), user: user)
      consolidated_notification =
        Fabricate(
          :notification,
          user: post.user,
          topic: post.topic,
          post_number: post.post_number,
          notification_type: Notification.types[:boost],
          data: {
            display_username: user.username,
            username2: other_user.username,
            count: 2,
            unique_usernames: [other_user.username, user.username],
            topic_title: post.topic.title,
          }.to_json,
        )

      boost_to_delete = Fabricate(:boost, post: post, user: user)
      boost_to_delete.destroy!

      consolidated_notification.reload
      data = JSON.parse(consolidated_notification.read_attribute(:data))
      expect(data["display_username"]).to eq(other_user.username)
      expect(data["username2"]).to be_nil
      expect(data["count"]).to be_nil
      expect(data["unique_usernames"]).to be_nil
      expect(data["boost_raw"]).to eq(other_boost.raw)
    end

    it "updates consolidated 3+ user notification when one user's boost is deleted" do
      third_user = Fabricate(:user)
      boost = Fabricate(:boost, post: post, user: user)
      consolidated_notification =
        Fabricate(
          :notification,
          user: post.user,
          topic: post.topic,
          post_number: post.post_number,
          notification_type: Notification.types[:boost],
          data: {
            display_username: user.username,
            username2: third_user.username,
            count: 3,
            unique_usernames: [other_user.username, third_user.username, user.username],
            topic_title: post.topic.title,
          }.to_json,
        )

      boost.destroy!

      consolidated_notification.reload
      data = JSON.parse(consolidated_notification.read_attribute(:data))
      expect(data["count"]).to eq(2)
      expect(data["unique_usernames"]).to contain_exactly(other_user.username, third_user.username)
      expect(data["display_username"]).to eq(third_user.username)
      expect(data["username2"]).to eq(other_user.username)
    end

    it "deletes consolidated notification when all users' boosts are deleted" do
      consolidated_notification =
        Fabricate(
          :notification,
          user: post.user,
          topic: post.topic,
          post_number: post.post_number,
          notification_type: Notification.types[:boost],
          data: {
            display_username: user.username,
            username2: other_user.username,
            count: 2,
            unique_usernames: [user.username],
            topic_title: post.topic.title,
          }.to_json,
        )

      boost = Fabricate(:boost, post: post, user: user)
      boost.destroy!

      expect(Notification.exists?(consolidated_notification.id)).to eq(false)
    end

    it "does not delete consolidated same-user notifications" do
      boost = Fabricate(:boost, post: post, user: user)
      consolidated_notification =
        Fabricate(
          :notification,
          user: post.user,
          topic: post.topic,
          post_number: post.post_number,
          notification_type: Notification.types[:boost],
          data: { display_username: user.username, consolidated: true, count: 3 }.to_json,
        )

      boost.destroy!

      expect(Notification.exists?(consolidated_notification.id)).to eq(true)
    end
  end

  describe "auto-cooking" do
    it "cooks raw on save" do
      boost = DiscourseBoosts::Boost.create!(post: post, user: user, raw: ":tada:")
      expect(boost.cooked).to include("emoji")
    end
  end

  describe "clean_raw" do
    it "strips zero-width spaces" do
      boost = DiscourseBoosts::Boost.create!(post: post, user: user, raw: "nice\u200B!")
      expect(boost.raw).to eq("nice!")
    end

    it "normalizes whitespaces" do
      boost = DiscourseBoosts::Boost.create!(post: post, user: user, raw: "nice\u00A0!")
      expect(boost.raw).to eq("nice !")
    end

    it "strips leading and trailing whitespace" do
      boost = DiscourseBoosts::Boost.create!(post: post, user: user, raw: "  nice!  ")
      expect(boost.raw).to eq("nice!")
    end
  end
end
