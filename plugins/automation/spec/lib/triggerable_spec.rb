# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe DiscourseAutomation::Triggerable do
  fab!(:automation) {
    Fabricate(
      :automation,
      trigger: 'foo'
    )
  }

  describe "#setting" do
    before do
      DiscourseAutomation::Triggerable.add('foo') do
        setting :bar, :baz
      end
    end

    it "returns the setting value" do
      triggerable = DiscourseAutomation::Triggerable.new(automation.trigger)

      expect(triggerable.settings[:bar]).to eq(:baz)
    end
  end

  describe "#enable_manual_trigger" do
    context "when used" do
      before do
        DiscourseAutomation::Triggerable.add('foo') do
          enable_manual_trigger
        end
      end

      it "returns the correct setting value" do
        triggerable = DiscourseAutomation::Triggerable.new(automation.trigger)
        expect(triggerable.settings[DiscourseAutomation::Triggerable::MANUAL_TRIGGER_KEY]).to eq(true)
      end
    end

    context "when not used" do
      before do
        DiscourseAutomation::Triggerable.add('foo')
      end

      it "returns the correct setting value" do
        triggerable = DiscourseAutomation::Triggerable.new(automation.trigger)

        expect(triggerable.settings[DiscourseAutomation::Triggerable::MANUAL_TRIGGER_KEY]).to eq(false)
      end
    end
  end
end
