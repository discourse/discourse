# frozen_string_literal: true

describe "UserGlobalNotice" do
  before { SiteSetting.discourse_automation_enabled = true }

  context "when triggered by a stalled topic" do
    fab!(:automation_1) do
      Fabricate(
        :automation,
        script: DiscourseAutomation::Scripts::USER_GLOBAL_NOTICE,
        trigger: "stalled_topic",
      )
    end

    fab!(:topic_1) { Fabricate(:topic) }

    before do
      automation_1.upsert_field!("stalled_after", "choices", { value: "PT1H" }, target: "trigger")
      automation_1.upsert_field!("notice", "message", { value: "foo bar" }, target: "script")
      automation_1.upsert_field!("level", "choices", { value: "error" }, target: "script")
    end

    describe "script" do
      describe "StalledTopic trigger" do
        it "creates a notice for the topic owner" do
          expect do
            automation_1.trigger!(
              "kind" => DiscourseAutomation::Triggers::STALLED_TOPIC,
              "topic" => topic_1,
            )
          end.to change { DiscourseAutomation::UserGlobalNotice.count }.by(1)

          user_notice = DiscourseAutomation::UserGlobalNotice.last
          expect(user_notice.user_id).to eq(topic_1.user_id)
          expect(user_notice.level).to eq("error")
          expect(user_notice.notice).to eq("foo bar")
        end
      end
    end

    it "creates and destroy global notices" do
      post = Fabricate(:post, created_at: 1.day.ago)

      expect { Jobs::DiscourseAutomation::StalledTopicTracker.new.execute }.to change {
        DiscourseAutomation::UserGlobalNotice.count
      }.by(1)

      expect {
        PostCreator.create!(post.user, topic_id: post.topic_id, raw: "lorem ipsum dolor sit amet")
      }.to change { DiscourseAutomation::UserGlobalNotice.count }.by(-1)
    end
  end

  context "when triggered by a first accepted solution" do
    fab!(:automation_1) do
      Fabricate(
        :automation,
        script: DiscourseAutomation::Scripts::USER_GLOBAL_NOTICE,
        trigger: "first_accepted_solution",
      )
    end

    fab!(:user_1) { Fabricate(:user, username: "user_solved_1") }
    fab!(:post_1) { Fabricate(:post, user: user_1) }

    before do
      automation_1.upsert_field!(
        "notice",
        "message",
        { value: "notice for {{username}}" },
        target: "script",
      )
      automation_1.upsert_field!("level", "choices", { value: "success" }, target: "script")
    end

    it "creates a notice for the solution author" do
      expect do
        automation_1.trigger!(
          "kind" => "first_accepted_solution",
          "accepted_post_id" => post_1.id,
          "usernames" => [post_1.user.username],
          "placeholders" => {
            "post_url" => Discourse.base_url + post_1.url,
          },
        )
      end.to change { DiscourseAutomation::UserGlobalNotice.count }.by(1)

      user_notice = DiscourseAutomation::UserGlobalNotice.last
      expect(user_notice.user_id).to eq(post_1.user.id)
      expect(user_notice.level).to eq("success")
      expect(user_notice.notice).to eq("notice for user_solved_1")
    end
  end

  describe "on_reset" do
    fab!(:topic_1) { Fabricate(:topic) }

    fab!(:automation_1) do
      Fabricate(:automation, script: DiscourseAutomation::Scripts::USER_GLOBAL_NOTICE)
    end

    fab!(:automation_2) do
      Fabricate(:automation, script: DiscourseAutomation::Scripts::USER_GLOBAL_NOTICE)
    end

    before do
      [automation_1, automation_2].each do |automation|
        automation.trigger!(
          "kind" => DiscourseAutomation::Triggers::STALLED_TOPIC,
          "topic" => topic_1,
        )
      end
    end

    it "destroys all existing notices" do
      klass = DiscourseAutomation::UserGlobalNotice

      expect(klass.exists?(identifier: automation_1.id)).to eq(true)
      expect(klass.exists?(identifier: automation_2.id)).to eq(true)

      automation_1.scriptable.on_reset.call(automation_1)

      expect(klass.exists?(identifier: automation_1.id)).to eq(false)
      expect(klass.exists?(identifier: automation_2.id)).to eq(true)
    end
  end
end
