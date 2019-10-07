# frozen_string_literal: true

require 'rails_helper'

describe DiscourseAutomation::Triggerable do
  before do
    DiscourseAutomation.reset!

    DiscourseAutomation::Triggerable.add(:foo) do
      field :user, type: :user
      field :firstname, type: :string, required: true
      field :lastname, type: :string, default: 'bob'

      trigger? do |args, options|
        false
      end
    end

    DiscourseAutomation::Triggerable.add(:user_created)
  end

  it 'has a list of triggerables' do
    expect(DiscourseAutomation::Triggerable.list.count).to eq(2)
  end

  context 'a custom type' do
    let(:triggerable) do
      DiscourseAutomation::Triggerable[:foo]
    end

    it 'has the type custom' do
      expect(triggerable[:type]).to eq(DiscourseAutomation::Trigger.types[:custom])
    end

    it 'has the correct key' do
      expect(triggerable[:key]).to eq(:foo)
    end

    it 'has fields' do
      fields = triggerable[:fields]
      expect(fields[:user]).to eq(type: :user, default: nil, required: false)
      expect(fields[:firstname]).to eq(type: :string, default: nil, required: true)
      expect(fields[:lastname]).to eq(type: :string, default: 'bob', required: false)
    end

    it 'has a trigger?' do
      expect(triggerable[:trigger].call).to be_falsy
    end
  end

  context 'an existing type' do
    let(:triggerable) do
      DiscourseAutomation::Triggerable[:user_created]
    end

    it 'has the expected type' do
      expect(triggerable[:type]).to eq(DiscourseAutomation::Trigger.types[:user_created])
    end

    it 'has no key' do
      expect(triggerable[:key]).to be_nil
    end
  end
end
