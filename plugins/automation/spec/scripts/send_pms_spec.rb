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
          { title: "Hello {{receiver_username}}", raw: "Message for @{{receiver_username}}" },
        ],
      },
    )
  end

  context "with stalled_wiki trigger" do
    fab!(:user) { Fabricate(:user, admin: true) }
    fab!(:post) { Fabricate(:post, user: user) }

    before do
      automation.upsert_field!("stalled_after", "choices", { value: "PT1H" }, target: "trigger")
      automation.upsert_field!("retriggered_after", "choices", { value: "PT1H" }, target: "trigger")
      post.revise(user, { wiki: true }, { force_new_version: true, revised_at: 2.hours.ago })
    end

    it "sends PM with placeholders replaced" do
      expect { Jobs::DiscourseAutomation::StalledWikiTracker.new.execute(nil) }.to change {
        Topic.where(archetype: Archetype.private_message).count
      }.by(1)

      pm = Topic.last
      expect(pm.title).to eq("Hello #{user.username}")
      expect(pm.first_post.raw).to eq("Message for @#{user.username}")
    end
  end

  context "with user_added_to_group trigger" do
    fab!(:user)
    fab!(:group)

    before do
      automation.update!(trigger: "user_added_to_group")
      automation.upsert_field!("joined_group", "group", { value: group.id }, target: "trigger")
    end

    it "sends PM when user joins group" do
      expect { group.add(user) }.to change {
        Topic.where(archetype: Archetype.private_message).count
      }.by(1)

      pm = Topic.last
      expect(pm.title).to eq("Hello #{user.username}")
      expect(pm.allowed_users).to include(user, Discourse.system_user)
    end

    context "with custom sender" do
      fab!(:sender) { Fabricate(:user, refresh_auto_groups: true) }
      fab!(:user_2) { Fabricate(:user, refresh_auto_groups: true) }

      before do
        SiteSetting.unique_posts_mins = 1
        automation.upsert_field!("sender", "user", { value: sender.username })
      end

      it "bypasses similarity validation for multiple recipients" do
        expect { group.add(user) }.to change { Topic.count }.by(1)
        expect { group.add(user_2) }.to change { Topic.count }.by(1)
      end
    end
  end

  context "with delay" do
    fab!(:user)

    before do
      automation.update!(trigger: DiscourseAutomation::Triggers::RECURRING)
      automation.upsert_field!("receiver", "user", { value: user.username })
      automation.upsert_field!(
        "sendable_pms",
        "pms",
        { value: [{ title: "Delayed", raw: "Content", delay: 5 }] },
      )
    end

    it "creates a pending PM instead of sending immediately" do
      expect { automation.trigger! }.to change { DiscourseAutomation::PendingPm.count }.by(
        1,
      ).and not_change { Topic.count }

      pending_pm = DiscourseAutomation::PendingPm.last
      expect(pending_pm.title).to eq("Delayed")
      expect(pending_pm.target_usernames).to eq([user.username])
      expect(pending_pm.execute_at).to be_within(1.minute).of(5.minutes.from_now)
    end
  end
end
