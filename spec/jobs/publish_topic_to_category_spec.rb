require 'rails_helper'

RSpec.describe Jobs::PublishTopicToCategory do
  let(:category) { Fabricate(:category) }
  let(:another_category) { Fabricate(:category) }

  let(:topic) do
    Fabricate(:topic, category: category, topic_timers: [
      Fabricate(:topic_timer,
        status_type: TopicTimer.types[:publish_to_category],
        category_id: another_category.id
      )
    ])
  end

  before do
    SiteSetting.queue_jobs = true
  end

  describe 'when topic_timer_id is invalid' do
    it 'should raise the right error' do
      expect { described_class.new.execute(topic_timer_id: -1) }
        .to raise_error(Discourse::InvalidParameters)
    end
  end

  describe 'when topic has been deleted' do
    it 'should not publish the topic to the new category' do
      Timecop.travel(1.hour.ago) { topic }
      topic.trash!

      described_class.new.execute(topic_timer_id: topic.topic_timer.id)

      topic.reload
      expect(topic.category).to eq(category)
      expect(topic.created_at).to be_within(1.second).of(Time.zone.now - 1.hour)
    end
  end

  it 'should publish the topic to the new category' do
    Timecop.travel(1.hour.ago) { topic.update!(visible: false) }

    message = MessageBus.track_publish do
      described_class.new.execute(topic_timer_id: topic.topic_timer.id)
    end.first

    topic.reload
    expect(topic.category).to eq(another_category)
    expect(topic.visible).to eq(true)
    expect(topic.topic_timer).to eq(nil)

    %w{created_at bumped_at updated_at last_posted_at}.each do |attribute|
      expect(topic.public_send(attribute)).to be_within(1.second).of(Time.zone.now)
    end

    expect(message.data[:reload_topic]).to be_present
    expect(message.data[:refresh_stream]).to be_present
  end

  describe 'when topic is a private message' do
    before do
      Timecop.travel(1.hour.ago) do
        expect { topic.convert_to_private_message(Discourse.system_user) }
          .to change { topic.private_message? }.to(true)
      end
    end


    it 'should publish the topic to the new category' do
      message = MessageBus.track_publish do
        described_class.new.execute(topic_timer_id: topic.topic_timer.id)
      end.last

      topic.reload
      expect(topic.category).to eq(another_category)
      expect(topic.visible).to eq(true)
      expect(topic.private_message?).to eq(false)

      %w{created_at bumped_at updated_at last_posted_at}.each do |attribute|
        expect(topic.public_send(attribute)).to be_within(1.second).of(Time.zone.now)
      end

      expect(message.data[:reload_topic]).to be_present
      expect(message.data[:refresh_stream]).to be_present
    end
  end
end
