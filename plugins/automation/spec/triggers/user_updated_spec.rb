# frozen_string_literal: true

require_relative "../discourse_automation_helper"

describe "UserUpdated" do
  before { SiteSetting.discourse_automation_enabled = true }
  fab!(:user_field_1) { Fabricate(:user_field, name: "custom field 1") }
  fab!(:user_field_2) { Fabricate(:user_field, name: "custom field 2") }

  fab!(:user) do
    user = Fabricate(:user, trust_level: TrustLevel[0])
    user.set_user_field(user_field_1.id, "Answer custom 1")
    user.set_user_field(user_field_2.id, "Answer custom 2")
    user.save
    user
  end

  fab!(:automation) do
    automation = Fabricate(:automation, trigger: DiscourseAutomation::Triggerable::USER_UPDATED)
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

  it "has the correct data" do
    script_input = capture_contexts { UserUpdater.new(user, user).update(location: "Japan") }
    script_input = script_input.first

    expect(script_input["kind"]).to eq(DiscourseAutomation::Triggerable::USER_UPDATED)
    expect(script_input["user"]).to eq(user)
    expect(script_input["user_data"].count).to eq(2)
    expect(script_input["user_data"][:custom_fields][user_field_1.name]).to eq(
      user.custom_fields["user_field_#{user_field_1.id}"],
    )
    expect(script_input["user_data"][:profile_data]["location"]).to eq("Japan")
  end
end
