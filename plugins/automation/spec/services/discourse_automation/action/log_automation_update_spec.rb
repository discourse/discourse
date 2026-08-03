# frozen_string_literal: true

RSpec.describe DiscourseAutomation::Action::LogAutomationUpdate do
  fab!(:admin)
  fab!(:automation) { Fabricate(:automation, name: "Test", enabled: true) }

  let(:guardian) { admin.guardian }
  let(:empty_value) { I18n.t("discourse_automation.staff_action_logs.empty_value") }

  let(:previous_automation_attributes) do
    {
      name: automation.name,
      script: automation.script,
      trigger: automation.trigger,
      enabled: automation.enabled,
      fields: automation.serialized_fields,
    }
  end

  it "does not log when nothing changed" do
    expect {
      described_class.call(automation, previous_automation_attributes, guardian)
    }.not_to change { UserHistory.count }
  end

  it "logs attribute changes with automation id" do
    automation.update!(name: "New Name", enabled: false)

    previous = previous_automation_attributes.merge(name: "Old Name", enabled: true)

    expect { described_class.call(automation, previous, guardian) }.to change {
      UserHistory.count
    }.by(1)
    expect(UserHistory.last).to have_attributes(
      custom_type: "update_automation",
      details:
        a_string_including(
          "id: #{automation.id}",
          "name: Old Name → New Name",
          "enabled: true → false",
        ),
    )
  end

  it "formats empty values" do
    automation.update!(name: "New Name")
    described_class.call(automation, previous_automation_attributes.merge(name: nil), guardian)
    expect(UserHistory.last.details).to include("name: #{empty_value} → New Name")

    automation.update!(name: "")
    described_class.call(
      automation,
      previous_automation_attributes.merge(name: "Old Name"),
      guardian,
    )
    expect(UserHistory.last.details).to include("name: Old Name → #{empty_value}")
  end

  context "with field changes" do
    fab!(:automation) do
      Fabricate(:automation, trigger: DiscourseAutomation::Triggers::POINT_IN_TIME)
    end

    it "logs field value changes" do
      original_time = 1.hour.from_now.iso8601
      new_time = 2.hours.from_now.iso8601

      automation.upsert_field!(
        "execute_at",
        "date_time",
        { "value" => new_time },
        target: "trigger",
      )
      described_class.call(
        automation,
        previous_automation_attributes.merge(
          fields: {
            "execute_at" => {
              "value" => original_time,
              "target" => "trigger",
            },
          },
        ),
        guardian,
      )

      expect(UserHistory.last.details).to include("execute_at: #{original_time} → #{new_time}")
    end
  end
end
