# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe 'UserGlobalNotice' do
  fab!(:automation_1) do
    Fabricate(
      :automation,
      script: DiscourseAutomation::Scriptable::USER_GLOBAL_NOTICE
    )
  end

  fab!(:topic_1) { Fabricate(:topic) }

  before do
    automation_1.upsert_field!('notice', 'message', { value: 'foo bar' }, target: 'script')
    automation_1.upsert_field!('level', 'choices', { value: 'error' }, target: 'script')
  end

  describe 'script' do
    context 'StalledTopic trigger' do
      it 'creates a notice for the topic owner' do
        expect do
          automation_1.trigger!(
            'kind' => DiscourseAutomation::Triggerable::STALLED_TOPIC,
            'topic' => topic_1
          )
        end.to change { DiscourseAutomation::UserGlobalNotice.count }.by(1)

        user_notice = DiscourseAutomation::UserGlobalNotice.last
        expect(user_notice.user_id).to eq(topic_1.user_id)
        expect(user_notice.level).to eq('error')
        expect(user_notice.notice).to eq('foo bar')
      end
    end
  end

  describe 'on_reset' do
    fab!(:automation_2) do
      Fabricate(
        :automation,
        script: DiscourseAutomation::Scriptable::USER_GLOBAL_NOTICE
      )
    end

    before do
      [automation_1, automation_2].each do |automation|
        automation.trigger!(
          'kind' => DiscourseAutomation::Triggerable::STALLED_TOPIC,
          'topic' => topic_1
        )
      end
    end

    it 'destroys all existing notices' do
      klass = DiscourseAutomation::UserGlobalNotice

      expect(klass.exists?(identifier: automation_1.id)).to eq(true)
      expect(klass.exists?(identifier: automation_2.id)).to eq(true)

      automation_1.scriptable.on_reset.call(automation_1)

      expect(klass.exists?(identifier: automation_1.id)).to eq(false)
      expect(klass.exists?(identifier: automation_2.id)).to eq(true)
    end
  end
end
