# frozen_string_literal: true

require_relative "../discourse_automation_helper"

describe "Post" do
  fab!(:topic_1) { Fabricate(:topic) }
  let!(:raw) { "this is me testing a post" }

  before { SiteSetting.discourse_automation_enabled = true }

  context "when using point_in_time trigger" do
    fab!(:automation) do
      Fabricate(
        :automation,
        script: DiscourseAutomation::Scriptable::POST,
        trigger: DiscourseAutomation::Triggerable::POINT_IN_TIME,
      )
    end

    before do
      automation.upsert_field!(
        "execute_at",
        "date_time",
        { value: 3.hours.from_now },
        target: "trigger",
      )
      automation.upsert_field!("topic", "text", { value: topic_1.id }, target: "script")
      automation.upsert_field!("post", "post", { value: raw }, target: "script")
    end

    it "creates expected post" do
      freeze_time 6.hours.from_now do
        expect {
          Jobs::DiscourseAutomationTracker.new.execute

          expect(topic_1.posts.last.raw).to eq(raw)
        }.to change { topic_1.posts.count }.by(1)
      end
    end

    context "when topic is deleted" do
      before { topic_1.trash! }

      it "does nothing and does not error" do
        freeze_time 6.hours.from_now do
          expect { Jobs::DiscourseAutomationTracker.new.execute }.not_to change { Post.count }
        end
      end
    end
  end

  context "when using recurring trigger" do
    fab!(:automation) do
      Fabricate(
        :automation,
        script: DiscourseAutomation::Scriptable::POST,
        trigger: DiscourseAutomation::Triggerable::RECURRING,
      )
    end

    before do
      automation.upsert_field!("topic", "text", { value: topic_1.id }, target: "script")
      automation.upsert_field!("post", "post", { value: raw }, target: "script")
    end

    it "creates expected post" do
      expect {
        automation.trigger!

        expect(topic_1.posts.last.raw).to eq(raw)
      }.to change { topic_1.posts.count }.by(1)
    end
  end

  context "when using user_updated trigger" do
    fab!(:user_field_1) { Fabricate(:user_field, name: "custom field 1") }
    fab!(:user_field_2) { Fabricate(:user_field, name: "custom field 2") }

    fab!(:user) do
      user = Fabricate(:user, trust_level: TrustLevel[0])
      user.set_user_field(user_field_1.id, "Answer custom 1")
      user.set_user_field(user_field_2.id, "Answer custom 2")
      user.user_profile.location = "Japan"
      user.user_profile.save
      user.save
      user
    end

    fab!(:automation) do
      automation =
        Fabricate(
          :automation,
          script: DiscourseAutomation::Scriptable::POST,
          trigger: DiscourseAutomation::Triggerable::USER_UPDATED,
        )
      automation.upsert_field!(
        "automation_name",
        "text",
        { value: "Automation Test" },
        target: "trigger",
      )
      automation.upsert_field!(
        "custom_fields",
        "custom_fields",
        { value: ["custom field 1", "custom field 2"] },
        target: "trigger",
      )
      automation.upsert_field!(
        "user_profile",
        "user_profile",
        { value: ["location"] },
        target: "trigger",
      )
      automation.upsert_field!("first_post_only", "boolean", { value: true }, target: "trigger")
      automation
    end
    let!(:user_raw_post) do
      "This is a raw test post for user custom field 1: %%CUSTOM_FIELD_1%%, custom field 2: %%CUSTOM_FIELD_2%% and location: %%LOCATION%%"
    end
    let!(:placeholder_applied_user_raw_post) do
      "This is a raw test post for user custom field 1: #{user.custom_fields["user_field_#{user_field_1.id}"]}, custom field 2: #{user.custom_fields["user_field_#{user_field_2.id}"]} and location: #{user.user_profile.location}"
    end

    before do
      automation.upsert_field!("topic", "text", { value: topic_1.id }, target: "script")
      automation.upsert_field!("post", "post", { value: user_raw_post }, target: "script")
    end

    it "Creates a post correctly" do
      expect {
        UserUpdater.new(user, user).update(location: "Japan")
        expect(topic_1.posts.last.raw).to eq(placeholder_applied_user_raw_post)
      }.to change { topic_1.posts.count }.by(1)
    end
  end
end
