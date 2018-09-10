require 'rails_helper'

RSpec.describe TopicTimer, type: :model do
  let(:topic_timer) {
    # we should not need to do this but somehow
    # fabricator is failing here
    TopicTimer.create!(
      user_id: -1,
      topic: Fabricate(:topic),
      execute_at: 1.hour.from_now,
      status_type: TopicTimer.types[:close]
    )
  }
  let(:topic) { Fabricate(:topic) }
  let(:admin) { Fabricate(:admin) }

  before do
    freeze_time Time.new(2018)
  end

  context "validations" do
    describe '#status_type' do
      it 'should ensure that only one active public topic status update exists' do
        topic_timer.update!(topic: topic)
        Fabricate(:topic_timer, deleted_at: Time.zone.now, topic: topic)

        expect { Fabricate(:topic_timer, topic: topic) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end

      it 'should ensure that only one active private topic timer exists per user' do
        Fabricate(:topic_timer, topic: topic, user: admin, status_type: TopicTimer.types[:reminder])

        expect { Fabricate(:topic_timer, topic: topic, user: admin, status_type: TopicTimer.types[:reminder]) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end

      it 'should allow users to have their own private topic timer' do
        expect do
          Fabricate(:topic_timer,
            topic: topic,
            user: Fabricate(:admin),
            status_type: TopicTimer.types[:reminder]
          )
        end.to_not raise_error
      end
    end

    describe '#execute_at' do
      describe 'when #execute_at is greater than #created_at' do
        it 'should be valid' do
          topic_timer = Fabricate.build(:topic_timer,
            execute_at: Time.zone.now + 1.hour,
            user: Fabricate(:user),
            topic: Fabricate(:topic)
          )

          expect(topic_timer).to be_valid
        end
      end

      describe 'when #execute_at is smaller than #created_at' do
        it 'should not be valid' do
          topic_timer = Fabricate.build(:topic_timer,
            execute_at: Time.zone.now - 1.hour,
            created_at: Time.zone.now,
            user: Fabricate(:user),
            topic: Fabricate(:topic)
          )

          expect(topic_timer).to_not be_valid
        end
      end
    end

    describe '#category_id' do
      describe 'when #status_type is publish_to_category' do
        describe 'when #category_id is not present' do
          it 'should not be valid' do
            topic_timer = Fabricate.build(:topic_timer,
              status_type: TopicTimer.types[:publish_to_category]
            )

            expect(topic_timer).to_not be_valid
            expect(topic_timer.errors.keys).to include(:category_id)
          end
        end

        describe 'when #category_id is present' do
          it 'should be valid' do
            topic_timer = Fabricate.build(:topic_timer,
              status_type: TopicTimer.types[:publish_to_category],
              category_id: Fabricate(:category).id,
              user: Fabricate(:user),
              topic: Fabricate(:topic)
            )

            expect(topic_timer).to be_valid
          end
        end
      end
    end
  end

  context 'callbacks' do
    describe 'when #execute_at and #user_id are not changed' do
      it 'should not schedule another to update topic' do
        Jobs.expects(:enqueue_at).with(
          topic_timer.execute_at,
          :toggle_topic_closed,
          topic_timer_id: topic_timer.id,
          state: true
        ).once

        topic_timer

        Jobs.expects(:cancel_scheduled_job).never

        topic_timer.update!(topic: Fabricate(:topic))
      end
    end

    describe 'when #execute_at value is changed' do
      it 'reschedules the job' do
        freeze_time
        topic_timer

        Jobs.expects(:cancel_scheduled_job).with(
          :toggle_topic_closed, topic_timer_id: topic_timer.id
        )

        Jobs.expects(:enqueue_at).with(
          3.days.from_now, :toggle_topic_closed,
          topic_timer_id: topic_timer.id,
          state: true
        )

        topic_timer.update!(execute_at: 3.days.from_now, created_at: Time.zone.now)
      end

      describe 'when execute_at is smaller than the current time' do
        it 'should enqueue the job immediately' do
          freeze_time
          topic_timer

          Jobs.expects(:enqueue_at).with(
            Time.zone.now, :toggle_topic_closed,
            topic_timer_id: topic_timer.id,
            state: true
          )

          topic_timer.update!(
            execute_at: Time.zone.now - 1.hour,
            created_at: Time.zone.now - 2.hour
          )
        end
      end
    end

    describe 'when user is changed' do
      it 'should update the job' do
        freeze_time
        topic_timer

        Jobs.expects(:cancel_scheduled_job).with(
          :toggle_topic_closed, topic_timer_id: topic_timer.id
        )

        admin = Fabricate(:admin)

        Jobs.expects(:enqueue_at).with(
          topic_timer.execute_at,
          :toggle_topic_closed,
          topic_timer_id: topic_timer.id,
          state: true
        )

        topic_timer.update!(user: admin)
      end
    end

    describe 'when a open topic status update is created for an open topic' do
      let(:topic) { Fabricate(:topic, closed: false) }

      let(:topic_timer) do
        Fabricate(:topic_timer,
          status_type: described_class.types[:open],
          topic: topic
        )
      end

      before do
        SiteSetting.queue_jobs = false
      end

      it 'should close the topic' do
        topic_timer
        expect(topic.reload.closed).to eq(true)
      end

      describe 'when topic has been deleted' do
        it 'should not queue the job' do
          topic.trash!
          topic_timer

          expect(Jobs::ToggleTopicClosed.jobs).to eq([])
        end
      end
    end

    describe 'when a close topic status update is created for a closed topic' do
      let(:topic) { Fabricate(:topic, closed: true) }

      let(:topic_timer) do
        Fabricate(:topic_timer,
          status_type: described_class.types[:close],
          topic: topic
        )
      end

      before do
        SiteSetting.queue_jobs = false
      end

      it 'should open the topic' do
        topic_timer
        expect(topic.reload.closed).to eq(false)
      end

      describe 'when topic has been deleted' do
        it 'should not queue the job' do
          topic.trash!
          topic_timer

          expect(Jobs::ToggleTopicClosed.jobs).to eq([])
        end
      end
    end

    describe '#public_type' do
      [:close, :open, :delete].each do |public_type|
        it "is true for #{public_type}" do
          timer = Fabricate(:topic_timer, status_type: described_class.types[public_type])
          expect(timer.public_type).to eq(true)
        end
      end

      it "is true for publish_to_category" do
        timer = Fabricate(:topic_timer, status_type: described_class.types[:publish_to_category], category: Fabricate(:category))
        expect(timer.public_type).to eq(true)
      end

      described_class.private_types.keys.each do |private_type|
        it "is false for #{private_type}" do
          timer = Fabricate(:topic_timer, status_type: described_class.types[private_type])
          expect(timer.public_type).to be_falsey
        end
      end
    end
  end

  describe '.ensure_consistency!' do
    it 'should enqueue jobs that have been missed' do
      close_topic_timer = Fabricate(:topic_timer,
        execute_at: Time.zone.now - 1.hour,
        created_at: Time.zone.now - 2.hour
      )

      open_topic_timer = Fabricate(:topic_timer,
        status_type: described_class.types[:open],
        execute_at: Time.zone.now - 1.hour,
        created_at: Time.zone.now - 2.hour,
        topic: Fabricate(:topic, closed: true)
      )

      Fabricate(:topic_timer, execute_at: Time.zone.now + 1.hour)

      Fabricate(:topic_timer,
        execute_at: Time.zone.now - 1.hour,
        created_at: Time.zone.now - 2.hour
      ).topic.trash!

      # creating topic timers already enqueues jobs
      # let's delete them to test ensure_consistency!
      Sidekiq::Worker.clear_all

      expect { described_class.ensure_consistency! }
        .to change { Jobs::ToggleTopicClosed.jobs.count }.by(2)

      job_args = Jobs::ToggleTopicClosed.jobs.first["args"].first

      expect(job_args["topic_timer_id"]).to eq(close_topic_timer.id)
      expect(job_args["state"]).to eq(true)

      job_args = Jobs::ToggleTopicClosed.jobs.last["args"].first

      expect(job_args["topic_timer_id"]).to eq(open_topic_timer.id)
      expect(job_args["state"]).to eq(false)
    end

    it "should enqueue remind me jobs that have been missed" do
      reminder = Fabricate(:topic_timer,
        status_type: described_class.types[:reminder],
        execute_at: Time.zone.now - 1.hour,
        created_at: Time.zone.now - 2.hour
      )

      # creating topic timers already enqueues jobs
      # let's delete them to test ensure_consistency!
      Sidekiq::Worker.clear_all

      expect { described_class.ensure_consistency! }
        .to change { Jobs::TopicReminder.jobs.count }.by(1)

      job_args = Jobs::TopicReminder.jobs.first["args"].first
      expect(job_args["topic_timer_id"]).to eq(reminder.id)
    end
  end
end
