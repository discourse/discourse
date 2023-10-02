# frozen_string_literal: true

require_relative "../discourse_automation_helper"

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
        Jobs::DiscourseAutomationTrigger.jobs.size
      }.by(1)
    end

    it "also runs the script properly" do
      Jobs.run_immediately!
      post = Fabricate(:post)
      user = post.user
      list = capture_contexts { automation.trigger!({ post: post, user: user, test: :test }) }
      expect(list[0]["post"].id).to eq(post.id)
      expect(list[0]["user"].id).to eq(user.id)
      expect(list[0]["test"]).to eq(:test)
    end
  end

  describe "#detach_custom_field" do
    fab!(:automation) { Fabricate(:automation) }

    it "expects a User/Topic/Post instance" do
      expect { automation.detach_custom_field(Invite.new) }.to raise_error(RuntimeError)
    end
  end

  describe "#attach_custom_field" do
    fab!(:automation) { Fabricate(:automation) }

    it "expects a User/Topic/Post instance" do
      expect { automation.attach_custom_field(Invite.new) }.to raise_error(RuntimeError)
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
end
