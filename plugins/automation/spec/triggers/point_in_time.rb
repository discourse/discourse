# frozen_string_literal: true

require_relative "../discourse_automation_helper"

describe "PointInTime" do
  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:automation) do
    Fabricate(:automation, trigger: DiscourseAutomation::Triggerable::POINT_IN_TIME)
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
end
