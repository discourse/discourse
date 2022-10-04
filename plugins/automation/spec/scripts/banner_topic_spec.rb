# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe 'BannerTopic' do
  before do
    automation.upsert_field!('topic_id', 'text', { value: topic.id })
  end

  fab!(:automation) do
    Fabricate(
      :automation,
      script: DiscourseAutomation::Scriptable::BANNER_TOPIC
    )
  end
  fab!(:topic) { Fabricate(:topic) }

  context 'when banner until is set' do
    before do
      freeze_time
      automation.upsert_field!('banner_until', 'date_time', { value: 10.days.from_now })
      automation.upsert_field!('topic_id', 'text', { value: topic.id })
    end

    it 'banners the topic' do
      expect(topic.bannered_until).to be_nil
      expect(topic.archetype).to eq(Archetype.default)

      automation.trigger!
      topic.reload

      expect(topic.bannered_until).to be_within_one_minute_of(10.days.from_now)
      expect(topic.archetype).to eq(Archetype.banner)
    end
  end

  context 'when banner until is not set' do
    it 'banners the topic' do
      expect(topic.bannered_until).to be_nil
      expect(topic.archetype).to eq(Archetype.default)

      automation.trigger!
      topic.reload

      expect(topic.bannered_until).to be_nil
      expect(topic.archetype).to eq(Archetype.banner)
    end
  end
end
