require 'rails_helper'

describe Jobs::ToggleTopicClosed do
  let(:admin) { Fabricate(:admin) }

  let(:topic) do
    Fabricate(:topic_timer, user: admin).topic
  end

  it 'should be able to close a topic' do
    topic

    freeze_time(61.minutes.from_now) do
      described_class.new.execute(
        topic_timer_id: topic.public_topic_timer.id,
        state: true
      )

      expect(topic.reload.closed).to eq(true)

      expect(Post.last.raw).to eq(I18n.t(
        'topic_statuses.autoclosed_enabled_minutes', count: 61
      ))
    end
  end

  describe 'opening a topic' do
    it 'should be work' do
      topic.update!(closed: true)

      freeze_time(61.minutes.from_now) do
        described_class.new.execute(
          topic_timer_id: topic.public_topic_timer.id,
          state: false
        )

        expect(topic.reload.closed).to eq(false)

        expect(Post.last.raw).to eq(I18n.t(
          'topic_statuses.autoclosed_disabled_minutes', count: 61
        ))
      end
    end

    describe 'when category has auto close configured' do
      let(:category) { Fabricate(:category, auto_close_hours: 5) }
      let(:topic) { Fabricate(:topic, category: category, closed: true) }

      it "should restore the category's auto close timer" do
        Fabricate(:topic_timer,
          status_type: TopicTimer.types[:open],
          topic: topic,
          user: admin
        )

        freeze_time(61.minutes.from_now) do
          described_class.new.execute(
            topic_timer_id: topic.public_topic_timer.id,
            state: false
          )

          expect(topic.reload.closed).to eq(false)

          topic_timer = topic.public_topic_timer

          expect(topic_timer.status_type).to eq(TopicTimer.types[:close])
          expect(topic_timer.execute_at).to eq(5.hours.from_now)
        end
      end
    end
  end

  describe 'when trying to close a topic that has been deleted' do
    it 'should not do anything' do
      topic.trash!

      Topic.any_instance.expects(:update_status).never

      described_class.new.execute(
        topic_timer_id: topic.public_topic_timer.id,
        state: true
      )
    end
  end

  describe 'when user is not authorized to close topics' do
    let(:topic) do
      Fabricate(:topic_timer, execute_at: 2.hours.from_now).topic
    end

    it 'should not do anything' do
      described_class.new.execute(
        topic_timer_id: topic.public_topic_timer.id,
        state: false
      )

      expect(topic.reload.closed).to eq(false)
    end
  end
end
