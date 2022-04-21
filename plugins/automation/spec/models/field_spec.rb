# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe DiscourseAutomation::Field do
  context 'post field' do
    DiscourseAutomation::Scriptable.add('test_post_field') do
      field :foo, component: :post
    end

    fab!(:automation) { Fabricate(:automation, script: 'test_post_field') }

    it 'works with an empty value' do
      field = DiscourseAutomation::Field.create(automation: automation, component: 'post', name: 'foo')
      expect(field).to be_valid
    end

    it 'works with a text value' do
      field = DiscourseAutomation::Field.create(automation: automation, component: 'post', name: 'foo', metadata: { value: 'foo' })
      expect(field).to be_valid
    end

    it 'doesn’t work with an object value' do
      field = DiscourseAutomation::Field.create(automation: automation, component: 'post', name: 'foo', metadata: { value: { x: 1 } })
      expect(field).to_not be_valid
    end
  end

  context 'period field' do
    DiscourseAutomation::Scriptable.add('test_period_field') do
      field :foo, component: :period
    end

    fab!(:automation) { Fabricate(:automation, script: 'test_period_field') }

    it 'works with an object value' do
      value = { interval: "2", frequency: "day" }
      field = DiscourseAutomation::Field.create(automation: automation, component: 'period', name: 'foo', metadata: { value: value })
      expect(field).to be_valid
    end
  end
end
