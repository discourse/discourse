# frozen_string_literal: true

describe DiscourseAutomation::Triggerable do
  before do
    DiscourseAutomation::Triggerable.add("cats_everywhere") do
      placeholder :foo
      placeholder :bar
      placeholder { |fields, automation| "baz-#{automation.id}" }
      placeholder { |fields, automation| ["foo-baz-#{automation.id}"] }
    end

    DiscourseAutomation::Triggerable.add("dog") { field :kind, component: :text }

    DiscourseAutomation::Scriptable.add("only_dogs") { triggerable! :dog, { kind: "good_boy" } }
  end

  fab!(:automation) { Fabricate(:automation, trigger: "foo") }

  describe "deprecated active automation API" do
    it "raises a deprecation error" do
      expect { DiscourseAutomation.set_active_automation(10) }.to raise_error(
        Discourse::Deprecation,
        /suppress_triggers/,
      )

      expect { DiscourseAutomation.get_active_automation }.to raise_error(
        Discourse::Deprecation,
        /suppress_triggers/,
      )
    end
  end

  describe "trigger suppression thread safety" do
    it "ensures suppressed triggers are thread-local" do
      DiscourseAutomation.suppress_triggers do
        thread = Thread.new { DiscourseAutomation.triggers_suppressed? }
        thread.join
        expect(thread.value).to eq(false)

        expect(DiscourseAutomation.triggers_suppressed?).to eq(true)
      end

      expect(DiscourseAutomation.triggers_suppressed?).to eq(false)
    end

    it "clears suppressed triggers after errors" do
      expect { DiscourseAutomation.suppress_triggers { raise "boom" } }.to raise_error("boom")

      expect(DiscourseAutomation.triggers_suppressed?).to eq(false)
    end

    it "requires a block without changing existing suppression" do
      DiscourseAutomation.suppress_triggers do
        expect { DiscourseAutomation.suppress_triggers }.to raise_error(
          StandardError,
          "Expecting a block",
        )

        expect(DiscourseAutomation.triggers_suppressed?).to eq(true)
      end

      expect(DiscourseAutomation.triggers_suppressed?).to eq(false)
    end
  end

  describe "recursion depth thread safety" do
    after do
      while DiscourseAutomation.recursion_depth.positive?
        DiscourseAutomation.decrement_recursion_depth
      end
    end

    it "ensures thread safety when setting recursion depth" do
      DiscourseAutomation.increment_recursion_depth

      thread = Thread.new { DiscourseAutomation.recursion_depth }
      thread.join
      expect(thread.value).to eq(0)

      expect(DiscourseAutomation.recursion_depth).to eq(1)
    end
  end

  describe "#setting" do
    before { DiscourseAutomation::Triggerable.add("foo") { setting :bar, :baz } }

    it "returns the setting value" do
      triggerable = DiscourseAutomation::Triggerable.new(automation.trigger)

      expect(triggerable.settings[:bar]).to eq(:baz)
    end
  end

  describe "#placeholders" do
    fab!(:automation) { Fabricate(:automation, trigger: "cats_everywhere") }

    it "returns the specified placeholders" do
      expect(automation.triggerable.placeholders).to eq(
        [:foo, :bar, :"baz-#{automation.id}", :"foo-baz-#{automation.id}"],
      )
    end
  end

  describe "#enable_manual_trigger" do
    context "when used" do
      before { DiscourseAutomation::Triggerable.add("foo") { enable_manual_trigger } }

      it "returns the correct setting value" do
        triggerable = DiscourseAutomation::Triggerable.new(automation.trigger)
        expect(triggerable.settings[DiscourseAutomation::Triggerable::MANUAL_TRIGGER_KEY]).to eq(
          true,
        )
      end
    end

    context "when not used" do
      before { DiscourseAutomation::Triggerable.add("foo") }

      it "returns the correct setting value" do
        triggerable = DiscourseAutomation::Triggerable.new(automation.trigger)

        expect(triggerable.settings[DiscourseAutomation::Triggerable::MANUAL_TRIGGER_KEY]).to eq(
          false,
        )
      end
    end
  end
end
