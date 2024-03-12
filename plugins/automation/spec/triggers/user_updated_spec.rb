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
      "custom_fields",
      "custom_fields",
      { value: ["custom field 1", "custom field 2"] },
      target: "trigger",
    )
    automation.upsert_field!(
      "user_profile",
      "user_profile",
      { value: %w[location bio_raw] },
      target: "trigger",
    )
    automation
  end

  context "when custom_fields and user_profile are blank" do
    let(:automation) do
      Fabricate(
        :automation,
        trigger: DiscourseAutomation::Triggerable::USER_UPDATED,
      ).tap do |automation|
        automation.upsert_field!("custom_fields", "custom_fields", { value: [] }, target: "trigger")
        automation.upsert_field!("user_profile", "user_profile", { value: [] }, target: "trigger")
      end
    end

    it "adds an error to the automation" do
      expect(automation.save).to eq(false)
      errors = automation.errors.full_messages
      expect(errors).to include(
        I18n.t("discourse_automation.triggerables.errors.custom_fields_or_user_profile_required"),
      )
    end
  end

  it "has the correct data" do
    output =
      capture_contexts { UserUpdater.new(user, user).update(location: "Japan", bio_raw: "fine") }
    output = output.first

    expect(output["kind"]).to eq(DiscourseAutomation::Triggerable::USER_UPDATED)
    expect(output["user"]).to eq(user)
    expect(output["user_data"].count).to eq(2)
    expect(output["user_data"][:custom_fields][user_field_1.name]).to eq(
      user.custom_fields["user_field_#{user_field_1.id}"],
    )
    expect(output["user_data"][:profile_data]["location"]).to eq("Japan")
  end

  context "when once_per_user is set" do
    before do
      automation.upsert_field!("once_per_user", "boolean", { value: true }, target: "trigger")
    end

    it "doesnt trigger if automation already triggered" do
      automation.attach_custom_field(user)

      output =
        capture_contexts { UserUpdater.new(user, user).update(location: "Japan", bio_raw: "fine") }

      expect(output).to eq([])
    end

    it "triggers once when automation has never triggered" do
      output =
        capture_contexts { UserUpdater.new(user, user).update(location: "Japan", bio_raw: "fine") }

      expect(output.first["kind"]).to eq("user_updated")

      output =
        capture_contexts { UserUpdater.new(user, user).update(location: "Japan", bio_raw: "fine") }

      expect(output).to eq([])
    end
  end

  context "when once_per_user is no set" do
    it "triggers every time" do
      output =
        capture_contexts { UserUpdater.new(user, user).update(location: "Japan", bio_raw: "fine") }

      expect(output.first["kind"]).to eq("user_updated")

      output =
        capture_contexts { UserUpdater.new(user, user).update(location: "Japan", bio_raw: "fine") }

      expect(output.first["kind"]).to eq("user_updated")
    end
  end

  context "when not all fields are set" do
    it "doesn’t trigger" do
      output =
        capture_contexts { UserUpdater.new(user, user).update(location: "Japan", bio_raw: "fine") }

      expect(output.first["kind"]).to eq("user_updated")
    end
  end

  context "when all fields are set" do
    it "triggers" do
      output =
        capture_contexts { UserUpdater.new(user, user).update(location: "Japan", bio_raw: "fine") }

      expect(output.first["kind"]).to eq("user_updated")
    end
  end
end
