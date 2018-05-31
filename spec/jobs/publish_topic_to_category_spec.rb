require 'rails_helper'

RSpec.describe Jobs::PublishTopicToCategory do
  let(:category) { Fabricate(:category) }
  let(:another_category) { Fabricate(:category) }

  let(:topic) do
    topic = Fabricate(:topic, category: category)

    Fabricate(:topic_timer,
      status_type: TopicTimer.types[:publish_to_category],
      category_id: another_category.id,
      topic: topic
    )

    topic
  end

  describe 'when topic has been deleted' do
    it 'should not publish the topic to the new category' do
      freeze_time 1.hour.ago
      topic

      freeze_time 1.hour.from_now
      topic.trash!

      described_class.new.execute(topic_timer_id: topic.public_topic_timer.id)

      topic.reload
      expect(topic.category).to eq(category)
      expect(topic.created_at).to be_within(1.second).of(Time.zone.now - 1.hour)
    end
  end

  it 'should publish the topic to the new category' do
    freeze_time 1.hour.ago do
      topic.update!(visible: false)
    end

    message = MessageBus.track_publish do
      described_class.new.execute(topic_timer_id: topic.public_topic_timer.id)
    end.find do |m|
      Hash === m.data && m.data.key?(:reload_topic)
    end

    topic.reload
    expect(topic.category).to eq(another_category)
    expect(topic.visible).to eq(true)
    expect(topic.public_topic_timer).to eq(nil)

    %w{created_at bumped_at updated_at last_posted_at}.each do |attribute|
      expect(topic.public_send(attribute)).to be_within(1.second).of(Time.zone.now)
    end

    expect(message.data[:reload_topic]).to be_present
    expect(message.data[:refresh_stream]).to be_present
  end

  describe 'when topic is a private message' do
    before do
      freeze_time 1.hour.ago do
        expect { topic.convert_to_private_message(Discourse.system_user) }
          .to change { topic.private_message? }.to(true)
      end
    end

    it 'should publish the topic to the new category' do
      message = MessageBus.track_publish do
        described_class.new.execute(topic_timer_id: topic.public_topic_timer.id)
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
