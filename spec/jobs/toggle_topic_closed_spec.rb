require 'rails_helper'

describe Jobs::ToggleTopicClosed do
  let(:admin) { Fabricate(:admin) }

  let(:topic) do
    Fabricate(:topic,
      topic_status_updates: [Fabricate(:topic_status_update, user: admin)]
    )
  end

  before do
    SiteSetting.queue_jobs = true
  end

  it 'should be able to close a topic' do
    topic

    Timecop.travel(1.hour.from_now) do
      described_class.new.execute(
        topic_status_update_id: topic.topic_status_update.id,
        state: true
      )

      expect(topic.reload.closed).to eq(true)

      expect(Post.last.raw).to eq(I18n.t(
        'topic_statuses.autoclosed_enabled_minutes', count: 60
      ))
    end
  end

  it 'should be able to open a topic' do
    topic.update!(closed: true)

    Timecop.travel(1.hour.from_now) do
      described_class.new.execute(
        topic_status_update_id: topic.topic_status_update.id,
        state: false
      )

      expect(topic.reload.closed).to eq(false)

      expect(Post.last.raw).to eq(I18n.t(
        'topic_statuses.autoclosed_disabled_minutes', count: 60
      ))
    end
  end

  describe 'when trying to close a topic that has been deleted' do
    it 'should not do anything' do
      topic.trash!

      Topic.any_instance.expects(:update_status).never

      described_class.new.execute(
        topic_status_update_id: topic.topic_status_update.id,
        state: true
      )
    end
  end

  describe 'when user is not authorized to close topics' do
    let(:topic) do
      Fabricate(:topic,
        topic_status_updates: [Fabricate(:topic_status_update, execute_at: 2.hours.from_now)]
      )
    end

    it 'should not do anything' do
      described_class.new.execute(
        topic_status_update_id: topic.topic_status_update.id,
        state: false
      )

      expect(topic.reload.closed).to eq(false)
    end
  end
end
