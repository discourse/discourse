# frozen_string_literal: true

describe "Topic" do
  let!(:raw) { "this is me testing a new topic by automation" }
  let!(:title) { "This is a new topic created by automation" }
  fab!(:category) { Fabricate(:category) }
  fab!(:tag1) { Fabricate(:tag) }
  fab!(:tag2) { Fabricate(:tag) }

  before { SiteSetting.discourse_automation_enabled = true }

  context "when using point_in_time trigger" do
    fab!(:automation) do
      Fabricate(
        :automation,
        script: DiscourseAutomation::Scripts::TOPIC,
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
      automation.upsert_field!("title", "text", { value: title }, target: "script")
      automation.upsert_field!("body", "post", { value: raw }, target: "script")
      automation.upsert_field!(
        "category",
        "category",
        { value: category.id.to_s },
        target: "script",
      )
    end

    it "creates expected topic" do
      freeze_time 6.hours.from_now do
        expect {
          Jobs::DiscourseAutomation::Tracker.new.execute

          topic = Topic.last
          expect(topic.category.id).to eq(category.id)
          expect(topic.title).to eq(title)
          expect(topic.posts.first.raw).to eq(raw)
        }.to change { Topic.count }.by(1)
      end
    end
  end

  context "when using recurring trigger" do
    fab!(:automation) do
      Fabricate(
        :automation,
        script: DiscourseAutomation::Scripts::TOPIC,
        trigger: DiscourseAutomation::Triggers::RECURRING,
      )
    end

    before do
      automation.upsert_field!("title", "text", { value: title }, target: "script")
      automation.upsert_field!("body", "post", { value: raw }, target: "script")
      automation.upsert_field!(
        "category",
        "category",
        { value: category.id.to_s },
        target: "script",
      )
    end

    it "creates expected topic" do
      expect {
        automation.trigger!

        topic = Topic.last
        expect(topic.category.id).to eq(category.id)
        expect(topic.title).to eq(title)
        expect(topic.posts.first.raw).to eq(raw)
      }.to change { Topic.count }.by(1)
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
          script: DiscourseAutomation::Scripts::TOPIC,
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
      automation
    end
    let!(:user_raw_post) do
      "This is a raw test post for user custom field 1: {{custom_field_1}}, custom field 2: {{custom_field_2}} and location: {{location}}"
    end
    let!(:placeholder_applied_user_raw_post) do
      "This is a raw test post for user custom field 1: #{user.custom_fields["user_field_#{user_field_1.id}"]}, custom field 2: #{user.custom_fields["user_field_#{user_field_2.id}"]} and location: #{user.user_profile.location}"
    end

    before do
      automation.upsert_field!(
        "title",
        "text",
        { value: "{{custom_field_1}} {{location}} this is a title" },
        target: "script",
      )
      automation.upsert_field!("body", "post", { value: user_raw_post }, target: "script")
      automation.upsert_field!(
        "category",
        "category",
        { value: category.id.to_s },
        target: "script",
      )
      automation.upsert_field!("tags", "tags", { value: %w[feedback automation] }, target: "script")
    end

    it "creates a topic correctly" do
      expect {
        UserUpdater.new(user, user).update(location: "Japan")

        topic = Topic.last
        expect(topic.category.id).to eq(category.id)
        expect(topic.title).to eq(
          "#{user.custom_fields["user_field_#{user_field_1.id}"]} #{user.user_profile.location} this is a title",
        )
        expect(topic.posts.first.raw).to eq(placeholder_applied_user_raw_post)
        expect(topic.tags.pluck(:name)).to contain_exactly("feedback", "automation")
      }.to change { Topic.count }.by(1)
    end

    context "when creator is one of accepted context" do
      before do
        automation.upsert_field!("creator", "user", { value: "updated_user" }, target: "script")
      end

      it "sets the creator to the topic creator" do
        expect { UserUpdater.new(user, user).update(location: "Japan") }.to change {
          Topic.where(user_id: user.id).count
        }.by(1)
      end
    end

    context "when creating the post fails" do
      let(:fake_logger) { FakeLogger.new }

      before { Rails.logger.broadcast_to(fake_logger) }

      after { Rails.logger.stop_broadcasting_to(fake_logger) }

      it "logs a warning" do
        expect { UserUpdater.new(user, user).update(location: "Japan") }.to change {
          Topic.count
        }.by(1)
        expect { UserUpdater.new(user, user).update(location: "Japan") }.not_to change {
          Topic.count
        }

        expect(Rails.logger.warnings.first).to match(/Title has already been used/)
      end
    end
  end
end
