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

  describe "active automation thread safety" do
    after { DiscourseAutomation.set_active_automation(nil) }

    it "ensurese thread safety when setting automation id" do
      DiscourseAutomation.set_active_automation(10)

      thread = Thread.new { DiscourseAutomation.get_active_automation }
      thread.join
      expect(thread.value).to eq(nil)

      expect(DiscourseAutomation.get_active_automation).to eq(10)
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
