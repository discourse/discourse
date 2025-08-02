# frozen_string_literal: true

describe DiscourseAutomation::Automation do
  describe "#trigger!" do
    context "when not enabled" do
      fab!(:automation) { Fabricate(:automation, enabled: false) }

      it "doesn’t do anything" do
        list = capture_contexts { automation.trigger!("Howdy!") }

        expect(list).to eq([])
      end
    end

    context "when enabled" do
      fab!(:automation) { Fabricate(:automation, enabled: true) }

      it "runs the script" do
        list = capture_contexts { automation.trigger!("Howdy!") }

        expect(list).to eq(["Howdy!"])
      end
    end
  end

  describe "when a script is meant to be triggered in the background" do
    fab!(:automation) do
      Fabricate(:automation, enabled: true, script: "test-background-scriptable")
    end

    before do
      DiscourseAutomation::Scriptable.add("test_background_scriptable") do
        run_in_background

        script do |context|
          DiscourseAutomation::CapturedContext.add(context)
          nil
        end
      end
    end

    it "runs a sidekiq job to trigger it" do
      expect { automation.trigger!({ val: "Howdy!" }) }.to change {
        Jobs::DiscourseAutomation::Trigger.jobs.size
      }.by(1)
    end
  end

  describe "#remove_id_from_custom_field" do
    fab!(:automation)

    it "expects a User/Topic/Post instance" do
      expect {
        automation.remove_id_from_custom_field(
          Invite.new,
          DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD,
        )
      }.to raise_error(RuntimeError)
    end
  end

  describe "#add_id_to_custom_field" do
    fab!(:automation)

    it "expects a User/Topic/Post instance" do
      expect {
        automation.add_id_to_custom_field(
          Invite.new,
          DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD,
        )
      }.to raise_error(RuntimeError)
    end
  end

  context "when automation’s script has a field with validor" do
    before do
      DiscourseAutomation::Scriptable.add("required_dogs") do
        field :dog, component: :text, validator: ->(input) { "must have dog" if input != "dog" }
      end
    end

    context "when validating automation" do
      fab!(:automation) { Fabricate(:automation, enabled: false, script: "required_dogs") }

      it "raises an error if invalid" do
        expect {
          automation.fields.create!(
            name: "dog",
            component: "text",
            metadata: {
              value: nil,
            },
            target: "script",
          )
        }.to raise_error(ActiveRecord::RecordInvalid, /must have dog/)
      end

      it "does nothing if valid" do
        expect {
          automation.fields.create!(
            name: "dog",
            component: "text",
            metadata: {
              value: "dog",
            },
            target: "script",
          )
        }.not_to raise_error
      end
    end
  end

  context "when automation’s script has a required field" do
    before do
      DiscourseAutomation::Scriptable.add("required_dogs") do
        field :dog, component: :text, required: true
      end
    end

    context "when field is not filled" do
      fab!(:automation) { Fabricate(:automation, enabled: false, script: "required_dogs") }

      context "when validating automation" do
        it "raises an error" do
          expect {
            automation.fields.create!(
              name: "dog",
              component: "text",
              metadata: {
                value: nil,
              },
              target: "script",
            )
          }.to raise_error(ActiveRecord::RecordInvalid, /dog/)
        end
      end
    end
  end

  context "when automation’s trigger has a required field" do
    before do
      DiscourseAutomation::Triggerable.add("required_dogs") do
        field :dog, component: :text, required: true
      end
    end

    context "when field is not filled" do
      fab!(:automation) { Fabricate(:automation, enabled: false, trigger: "required_dogs") }

      context "when validating automation" do
        it "raises an error" do
          expect {
            automation.fields.create!(
              name: "dog",
              component: "text",
              metadata: {
                value: nil,
              },
              target: "trigger",
            )
          }.to raise_error(ActiveRecord::RecordInvalid, /dog/)
        end
      end
    end
  end

  describe "after_destroy" do
    fab!(:automation) { Fabricate(:automation, enabled: false) }
    fab!(:automation2) { Fabricate(:automation, enabled: false) }

    it "deletes user custom fields that indicate new users" do
      user = Fabricate(:user)
      user.custom_fields[automation.new_user_custom_field_name] = "1"
      user.custom_fields[automation2.new_user_custom_field_name] = "1"
      user.save_custom_fields

      automation.destroy!
      user.reload

      expect(user.custom_fields).to eq({ automation2.new_user_custom_field_name => "1" })
    end
  end

  context "when creating a new automation" do
    it "validates the name length" do
      automation = Fabricate.build(:automation, name: "a" * 101)
      expect(automation).not_to be_valid
      expect(automation.errors[:name]).to eq(["is too long (maximum is 100 characters)"])

      automation = Fabricate.build(:automation, name: "c" * 50)
      expect(automation).to be_valid
    end
  end
end
