# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe DiscourseAutomation::Automation do
  describe '#trigger!' do
    context 'is not enabled' do
      fab!(:automation) { Fabricate(:automation, enabled: false) }

      it 'doesn’t do anything' do
        output = capture_stdout do
          automation.trigger!('Howdy!')
        end

        expect(output).to_not include('Howdy!')
      end
    end

    context 'is enabled' do
      fab!(:automation) { Fabricate(:automation, enabled: true) }

      it 'runs the script' do
        output = capture_stdout do
          automation.trigger!('Howdy!')
        end

        expect(output).to include('Howdy!')
      end
    end
  end
end
