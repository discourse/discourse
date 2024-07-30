# frozen_string_literal: true

describe "PointInTime" do
  fab!(:user)
  fab!(:topic)
  fab!(:automation) do
    Fabricate(:automation, trigger: DiscourseAutomation::Triggers::POINT_IN_TIME)
  end

  context "when updating trigger" do
    context "when date is in future" do
      it "creates a pending automation" do
        expect {
          automation.upsert_field!(
            "execute_at",
            "date_time",
            { value: 2.hours.from_now },
            target: "trigger",
          )
        }.to change { DiscourseAutomation::PendingAutomation.count }.by(1)

        expect(DiscourseAutomation::PendingAutomation.last.execute_at).to be_within_one_minute_of(
          2.hours.from_now,
        )
      end
    end

    context "when date is in past" do
      it "doesn’t create a pending automation" do
        expect {
          automation.upsert_field!(
            "execute_at",
            "date_time",
            { value: 2.hours.ago },
            target: "trigger",
          )
        }.not_to change { DiscourseAutomation::PendingAutomation.count }
      end
    end
  end

  context "when updating automation" do
    fab!(:automation) do
      Fabricate(:automation, trigger: DiscourseAutomation::Triggers::POINT_IN_TIME, script: "test")
    end

    before do
      DiscourseAutomation::Scriptable.add("test") do
        triggerables [DiscourseAutomation::Triggers::POINT_IN_TIME]
        field :test, component: :text
      end

      automation.upsert_field!(
        "execute_at",
        "date_time",
        { value: 2.hours.from_now },
        target: "trigger",
      )

      automation.upsert_field!("test", "text", { value: "something" }, target: "script")
    end

    context "when execute_at changes" do
      it "resets the pending automations" do
        expect {
          automation.upsert_field!(
            "execute_at",
            "date_time",
            { value: 3.hours.from_now },
            target: "trigger",
          )
        }.to change { DiscourseAutomation::PendingAutomation.last.execute_at }
        expect(DiscourseAutomation::PendingAutomation.count).to eq(1)
      end
    end

    context "when a field other than execute_at changes" do
      it "doesn't reset the pending automations" do
        expect {
          automation.upsert_field!("test", "text", { value: "somethingelse" }, target: "script")
        }.to_not change { DiscourseAutomation::PendingAutomation.last.execute_at }
        expect(DiscourseAutomation::PendingAutomation.count).to eq(1)
      end
    end
  end
end
