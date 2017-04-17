require 'rails_helper'

RSpec.describe TopicStatusUpdate, type: :model do
  let(:topic_status_update) { Fabricate(:topic_status_update) }
  let(:topic) { Fabricate(:topic) }

  before do
    Jobs::ToggleTopicClosed.jobs.clear
  end

  context "validations" do
    describe '#status_type' do
      it 'should ensure that only one active topic status update exists' do
        topic_status_update.update!(topic: topic)
        Fabricate(:topic_status_update, deleted_at: Time.zone.now, topic: topic)

        expect { Fabricate(:topic_status_update, topic: topic) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    describe '#execute_at' do
      describe 'when #execute_at is greater than #created_at' do
        it 'should be valid' do
          topic_status_update = Fabricate.build(:topic_status_update,
            execute_at: Time.zone.now + 1.hour,
            user: Fabricate(:user),
            topic: Fabricate(:topic)
          )

          expect(topic_status_update).to be_valid
        end
      end

      describe 'when #execute_at is smaller than #created_at' do
        it 'should not be valid' do
          topic_status_update = Fabricate.build(:topic_status_update,
            execute_at: Time.zone.now - 1.hour,
            created_at: Time.zone.now,
            user: Fabricate(:user),
            topic: Fabricate(:topic)
          )

          expect(topic_status_update).to_not be_valid
        end
      end
    end

    describe '#category_id' do
      describe 'when #status_type is publish_to_category' do
        describe 'when #category_id is not present' do
          it 'should not be valid' do
            topic_status_update = Fabricate.build(:topic_status_update,
              status_type: TopicStatusUpdate.types[:publish_to_category]
            )

            expect(topic_status_update).to_not be_valid
            expect(topic_status_update.errors.keys).to include(:category_id)
          end
        end

        describe 'when #category_id is present' do
          it 'should be valid' do
            topic_status_update = Fabricate.build(:topic_status_update,
              status_type: TopicStatusUpdate.types[:publish_to_category],
              category_id: Fabricate(:category).id,
              user: Fabricate(:user),
              topic: Fabricate(:topic)
            )

            expect(topic_status_update).to be_valid
          end
        end
      end
    end
  end

  context 'callbacks' do
    describe 'when #execute_at and #user_id are not changed' do
      it 'should not schedule another to update topic' do
        Jobs.expects(:enqueue_at).with(
          topic_status_update.execute_at,
          :toggle_topic_closed,
          topic_status_update_id: topic_status_update.id,
          state: true
        ).once

        topic_status_update

        Jobs.expects(:cancel_scheduled_job).never

        topic_status_update.update!(topic: Fabricate(:topic))
      end
    end

    describe 'when #execute_at value is changed' do
      it 'reschedules the job' do
        Timecop.freeze do
          topic_status_update

          Jobs.expects(:cancel_scheduled_job).with(
            :toggle_topic_closed, topic_status_update_id: topic_status_update.id
          )

          Jobs.expects(:enqueue_at).with(
            3.days.from_now, :toggle_topic_closed,
            topic_status_update_id: topic_status_update.id,
            state: true
          )

          topic_status_update.update!(execute_at: 3.days.from_now, created_at: Time.zone.now)
        end
      end

      describe 'when execute_at is smaller than the current time' do
        it 'should enqueue the job immediately' do
          Timecop.freeze do
            topic_status_update

            Jobs.expects(:enqueue_at).with(
              Time.zone.now, :toggle_topic_closed,
              topic_status_update_id: topic_status_update.id,
              state: true
            )

            topic_status_update.update!(
              execute_at: Time.zone.now - 1.hour,
              created_at: Time.zone.now - 2.hour
            )
          end
        end
      end
    end

    describe 'when user is changed' do
      it 'should update the job' do
        Timecop.freeze do
          topic_status_update

          Jobs.expects(:cancel_scheduled_job).with(
            :toggle_topic_closed, topic_status_update_id: topic_status_update.id
          )

          admin = Fabricate(:admin)

          Jobs.expects(:enqueue_at).with(
            topic_status_update.execute_at,
            :toggle_topic_closed,
            topic_status_update_id: topic_status_update.id,
            state: true
          )

          topic_status_update.update!(user: admin)
        end
      end
    end

    describe 'when a open topic status update is created for an open topic' do
      let(:topic) { Fabricate(:topic, closed: false) }

      let(:topic_status_update) do
        Fabricate(:topic_status_update,
          status_type: described_class.types[:open],
          topic: topic
        )
      end

      it 'should close the topic' do
        topic_status_update
        expect(topic.reload.closed).to eq(true)
      end

      describe 'when topic has been deleted' do
        it 'should not queue the job' do
          topic.trash!
          topic_status_update

          expect(Jobs::ToggleTopicClosed.jobs).to eq([])
        end
      end
    end

    describe 'when a close topic status update is created for a closed topic' do
      let(:topic) { Fabricate(:topic, closed: true) }

      let(:topic_status_update) do
        Fabricate(:topic_status_update,
          status_type: described_class.types[:close],
          topic: topic
        )
      end

      it 'should open the topic' do
        topic_status_update
        expect(topic.reload.closed).to eq(false)
      end

      describe 'when topic has been deleted' do
        it 'should not queue the job' do
          topic.trash!
          topic_status_update

          expect(Jobs::ToggleTopicClosed.jobs).to eq([])
        end
      end
    end
  end

  describe '.ensure_consistency!' do
    before do
      SiteSetting.queue_jobs = true
      Jobs::ToggleTopicClosed.jobs.clear
    end

    it 'should enqueue jobs that have been missed' do
      close_topic_status_update = Fabricate(:topic_status_update,
        execute_at: Time.zone.now - 1.hour,
        created_at: Time.zone.now - 2.hour
      )

      open_topic_status_update = Fabricate(:topic_status_update,
        status_type: described_class.types[:open],
        execute_at: Time.zone.now - 1.hour,
        created_at: Time.zone.now - 2.hour
      )

      Fabricate(:topic_status_update)

      Fabricate(:topic_status_update,
        execute_at: Time.zone.now - 1.hour,
        created_at: Time.zone.now - 2.hour
      ).topic.trash!

      expect { described_class.ensure_consistency! }
        .to change { Jobs::ToggleTopicClosed.jobs.count }.by(2)

      job_args = Jobs::ToggleTopicClosed.jobs.first["args"].first

      expect(job_args["topic_status_update_id"]).to eq(close_topic_status_update.id)
      expect(job_args["state"]).to eq(true)

      job_args = Jobs::ToggleTopicClosed.jobs.last["args"].first

      expect(job_args["topic_status_update_id"]).to eq(open_topic_status_update.id)
      expect(job_args["state"]).to eq(false)
    end
  end
end
