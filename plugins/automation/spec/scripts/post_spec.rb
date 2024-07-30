# frozen_string_literal: true

describe "Post" do
  fab!(:topic_1) { Fabricate(:topic) }
  let!(:raw) { "this is me testing a post" }

  before { SiteSetting.discourse_automation_enabled = true }

  context "when using point_in_time trigger" do
    fab!(:automation) do
      Fabricate(
        :automation,
        script: DiscourseAutomation::Scripts::POST,
        trigger: DiscourseAutomation::Triggers::POINT_IN_TIME,
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
          Jobs::DiscourseAutomation::Tracker.new.execute

          expect(topic_1.posts.last.raw).to eq(raw)
        }.to change { topic_1.posts.count }.by(1)
      end
    end

    context "when topic is deleted" do
      before { topic_1.trash! }

      it "does nothing and does not error" do
        freeze_time 6.hours.from_now do
          expect { Jobs::DiscourseAutomation::Tracker.new.execute }.not_to change { Post.count }
        end
      end
    end
  end

  context "when using recurring trigger" do
    fab!(:automation) do
      Fabricate(
        :automation,
        script: DiscourseAutomation::Scripts::POST,
        trigger: DiscourseAutomation::Triggers::RECURRING,
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

    it "does not create post on a closed topic" do
      topic_1.update_status(:closed, true, topic_1.user)

      expect { automation.trigger! }.not_to change { topic_1.posts.count }
    end

    it "does not create post on an archived topic" do
      topic_1.update_status(:archived, true, topic_1.user)

      expect { automation.trigger! }.not_to change { topic_1.posts.count }
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
          script: DiscourseAutomation::Scripts::POST,
          trigger: DiscourseAutomation::Triggers::USER_UPDATED,
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
      "This is a raw test post for user custom field 1: {{custom_field_1}}, custom field 2: {{custom_field_2}} and location: {{location}}"
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

    context "when creator is one of accepted context" do
      before do
        automation.upsert_field!("creator", "user", { value: "updated_user" }, target: "script")
      end

      it "sets the creator to the post creator" do
        expect { UserUpdater.new(user, user).update(location: "Japan") }.to change {
          Post.where(user_id: user.id).count
        }.by(1)
      end
    end
  end
end
