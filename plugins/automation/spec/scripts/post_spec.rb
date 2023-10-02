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
end
