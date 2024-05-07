# frozen_string_literal: true

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
    automation = Fabricate(:automation, trigger: DiscourseAutomation::Triggers::USER_UPDATED)
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
        trigger: DiscourseAutomation::Triggers::USER_UPDATED,
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

    expect(output["kind"]).to eq(DiscourseAutomation::Triggers::USER_UPDATED)
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

  context "when once_per_user is not set" do
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

  context "when new_users_only is set" do
    before do
      automation.upsert_field!("new_users_only", "boolean", { value: true }, target: "trigger")
    end

    it "triggers for new users" do
      user = nil
      output =
        capture_contexts do
          user = Fabricate(:user)
          user.set_user_field(user_field_1.id, "Answer new custom 1")
          user.set_user_field(user_field_2.id, "Answer new custom 2")
          UserUpdater.new(user, user).update(location: "Japan", bio_raw: "fine")
        end

      expect(output.size).to eq(1)
      expect(output.first["kind"]).to eq("user_updated")
      expect(output.first["user"].id).to eq(user.id)
      expect(output.first["user_data"][:custom_fields]).to eq(
        { "custom field 1" => "Answer new custom 1", "custom field 2" => "Answer new custom 2" },
      )
      expect(output.first["user_data"][:profile_data]["location"]).to eq("Japan")
      expect(output.first["user_data"][:profile_data]["bio_raw"]).to eq("fine")

      output =
        capture_contexts do
          UserUpdater.new(user, user).update(location: "Japan22", bio_raw: "finegood")
        end
      expect(output.size).to eq(1)
      expect(output.first["kind"]).to eq("user_updated")
      expect(output.first["user"].id).to eq(user.id)
      expect(output.first["user_data"][:profile_data]["location"]).to eq("Japan22")
      expect(output.first["user_data"][:profile_data]["bio_raw"]).to eq("finegood")
    end

    it "doesn't trigger for existing users" do
      output =
        capture_contexts { UserUpdater.new(user, user).update(location: "Japan", bio_raw: "fine") }

      expect(output).to eq([])
    end

    context "when once_per_user is set" do
      before do
        automation.upsert_field!("once_per_user", "boolean", { value: true }, target: "trigger")
      end

      it "triggers only once for a new user" do
        user = nil
        output =
          capture_contexts do
            user = Fabricate(:user)
            user.set_user_field(user_field_1.id, "Answer new custom 1")
            user.set_user_field(user_field_2.id, "Answer new custom 2")
            UserUpdater.new(user, user).update(location: "Japan", bio_raw: "fine")
          end

        expect(output.size).to eq(1)
        expect(output.first["kind"]).to eq("user_updated")
        expect(output.first["user"].id).to eq(user.id)
        expect(output.first["user_data"][:custom_fields]).to eq(
          { "custom field 1" => "Answer new custom 1", "custom field 2" => "Answer new custom 2" },
        )
        expect(output.first["user_data"][:profile_data]["location"]).to eq("Japan")
        expect(output.first["user_data"][:profile_data]["bio_raw"]).to eq("fine")

        output =
          capture_contexts do
            UserUpdater.new(user, user).update(location: "Japan22", bio_raw: "finegood")
          end
        expect(output).to eq([])
      end

      it "doesn't trigger for an existing user" do
        output =
          capture_contexts do
            UserUpdater.new(user, user).update(location: "Japan", bio_raw: "fine")
          end

        expect(output).to eq([])
      end
    end
  end

  context "when new_users_only is not set" do
    before do
      automation.upsert_field!("new_users_only", "boolean", { value: false }, target: "trigger")
    end

    it "triggers for new users" do
      user = nil
      output =
        capture_contexts do
          user = Fabricate(:user)
          user.set_user_field(user_field_1.id, "Answer new custom 1")
          user.set_user_field(user_field_2.id, "Answer new custom 2")
          UserUpdater.new(user, user).update(location: "Japan", bio_raw: "fine")
        end

      expect(output.size).to eq(1)
      expect(output.first["kind"]).to eq("user_updated")
      expect(output.first["user"].id).to eq(user.id)
      expect(output.first["user_data"][:custom_fields]).to eq(
        { "custom field 1" => "Answer new custom 1", "custom field 2" => "Answer new custom 2" },
      )
      expect(output.first["user_data"][:profile_data]["location"]).to eq("Japan")
      expect(output.first["user_data"][:profile_data]["bio_raw"]).to eq("fine")
    end

    it "triggers for existing users" do
      output =
        capture_contexts { UserUpdater.new(user, user).update(location: "Japan", bio_raw: "fine") }

      expect(output.size).to eq(1)
      expect(output.first["kind"]).to eq("user_updated")
      expect(output.first["user"].id).to eq(user.id)
      expect(output.first["user_data"][:custom_fields]).to eq(
        { "custom field 1" => "Answer custom 1", "custom field 2" => "Answer custom 2" },
      )
      expect(output.first["user_data"][:profile_data]["location"]).to eq("Japan")
      expect(output.first["user_data"][:profile_data]["bio_raw"]).to eq("fine")

      output =
        capture_contexts do
          UserUpdater.new(user, user).update(location: "Japan22", bio_raw: "finegood")
        end
      expect(output.size).to eq(1)
      expect(output.first["kind"]).to eq("user_updated")
      expect(output.first["user"].id).to eq(user.id)
      expect(output.first["user_data"][:profile_data]["location"]).to eq("Japan22")
      expect(output.first["user_data"][:profile_data]["bio_raw"]).to eq("finegood")
    end
  end
end
