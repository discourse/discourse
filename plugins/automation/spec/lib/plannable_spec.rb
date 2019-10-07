# frozen_string_literal: true

require 'rails_helper'

describe DiscourseAutomation::Plannable do
  before do
    DiscourseAutomation.reset!

    DiscourseAutomation::Plannable.add(:foo) do
      field :user, type: :user
      field :firstname, type: :string, required: true
      field :lastname, type: :string, default: 'bob'

      plan! do |args, placeholders|
        { args: args, placeholders: placeholders }
      end
    end

    DiscourseAutomation::Plannable.add(:send_personal_message)
  end

  it 'has a list of plannables' do
    expect(DiscourseAutomation::Plannable.list.count).to eq(2)
  end

  context 'a custom type' do
    let(:plannable) do
      DiscourseAutomation::Plannable[:foo]
    end

    it 'has the type custom' do
      expect(plannable[:type]).to eq(DiscourseAutomation::Plan.types[:custom])
    end

    it 'has the correct key' do
      expect(plannable[:key]).to eq(:foo)
    end

    it 'has fields' do
      fields = plannable[:fields]
      expect(fields[:user]).to eq(type: :user, default: nil, required: false)
      expect(fields[:firstname]).to eq(type: :string, default: nil, required: true)
      expect(fields[:lastname]).to eq(type: :string, default: 'bob', required: false)
    end

    it 'has a plan!' do
      expect(plannable[:plan].call).to eq({args: {}, placeholders: {}})
    end
  end

  context 'an existing type' do
    let(:plannable) do
      DiscourseAutomation::Plannable[:send_personal_message]
    end

    it 'has the expected type' do
      expect(plannable[:type]).to eq(DiscourseAutomation::Plan.types[:send_personal_message])
    end

    it 'has the correct key' do
      expect(plannable[:key]).to eq(:send_personal_message)
    end
  end
end
