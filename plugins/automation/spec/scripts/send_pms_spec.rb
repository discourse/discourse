# frozen_string_literal: true

describe "SendPms" do
  fab!(:automation) do
    Fabricate(:automation, script: DiscourseAutomation::Scripts::SEND_PMS, trigger: "stalled_wiki")
  end

  before do
    SiteSetting.discourse_automation_enabled = true

    automation.upsert_field!("sender", "user", { value: Discourse.system_user.username })
    automation.upsert_field!(
      "sendable_pms",
      "pms",
      {
        value: [
          {
            title: "A message from {{sender_username}}",
            raw: "This is a message sent to @{{receiver_username}}",
          },
        ],
      },
    )
  end

  context "when run from stalled_wiki trigger" do
    fab!(:post_creator_1) { Fabricate(:user, admin: true) }
    fab!(:post_1) { Fabricate(:post, user: post_creator_1) }

    before do
      automation.upsert_field!("stalled_after", "choices", { value: "PT1H" }, target: "trigger")
      automation.upsert_field!("retriggered_after", "choices", { value: "PT1H" }, target: "trigger")

      post_1.revise(
        post_creator_1,
        { wiki: true },
        { force_new_version: true, revised_at: 2.hours.ago },
      )
    end

    it "creates expected PM" do
      expect {
        Jobs::DiscourseAutomation::StalledWikiTracker.new.execute(nil)

        post = Post.last
        expect(post.topic.title).to eq("A message from #{Discourse.system_user.username}")
        expect(post.raw).to eq("This is a message sent to @#{post_creator_1.username}")
        expect(post.topic.topic_allowed_users.exists?(user_id: post_creator_1.id)).to eq(true)
        expect(post.topic.topic_allowed_users.exists?(user_id: Discourse.system_user.id)).to eq(
          true,
        )
      }.to change { Post.count }.by(1)
    end
  end

  context "when run from user_added_to_group trigger" do
    fab!(:user_1) { Fabricate(:user) }
    fab!(:tracked_group_1) { Fabricate(:group) }

    before do
      automation.update!(trigger: "user_added_to_group")
      automation.upsert_field!(
        "joined_group",
        "group",
        { value: tracked_group_1.id },
        target: "trigger",
      )
    end

    it "creates expected PM" do
      expect {
        tracked_group_1.add(user_1)

        post = Post.last
        expect(post.topic.title).to eq("A message from #{Discourse.system_user.username}")
        expect(post.raw).to eq("This is a message sent to @#{user_1.username}")
        expect(post.topic.topic_allowed_users.exists?(user_id: user_1.id)).to eq(true)
        expect(post.topic.topic_allowed_users.exists?(user_id: Discourse.system_user.id)).to eq(
          true,
        )
      }.to change { Post.count }.by(1)
    end
  end

  context "when delayed" do
    fab!(:user_1) { Fabricate(:user) }

    before { automation.update!(trigger: DiscourseAutomation::Triggers::RECURRING) }

    it "correctly sets encrypt preference to false even when option is not specified" do
      automation.upsert_field!(
        "sendable_pms",
        "pms",
        {
          value: [
            {
              title: "A message from {{sender_username}}",
              raw: "This is a message sent to @{{receiver_username}}",
              delay: 1,
            },
          ],
        },
        target: "script",
      )
      automation.upsert_field!("receiver", "user", { value: Discourse.system_user.username })

      automation.trigger!

      expect(DiscourseAutomation::PendingPm.last.prefers_encrypt).to eq(false)
    end

    it "correctly stores encrypt preference to false" do
      automation.upsert_field!(
        "sendable_pms",
        "pms",
        {
          value: [
            {
              title: "A message from {{sender_username}}",
              raw: "This is a message sent to @{{receiver_username}}",
              delay: 1,
              prefers_encrypt: false,
            },
          ],
        },
        target: "script",
      )
      automation.upsert_field!("receiver", "user", { value: Discourse.system_user.username })

      automation.trigger!

      expect(DiscourseAutomation::PendingPm.last.prefers_encrypt).to eq(false)
    end
  end
end
