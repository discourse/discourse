# encoding: UTF-8

require 'rails_helper'

describe Topic do
  let(:job_klass) { Jobs::ToggleTopicClosed }

  context 'creating a topic without auto-close' do
    let(:topic) { Fabricate(:topic, category: category) }

    context 'uncategorized' do
      let(:category) { nil }

      it 'should not schedule the topic to auto-close' do
        expect(topic.public_topic_timer).to eq(nil)
        expect(job_klass.jobs).to eq([])
      end
    end

    context 'category without default auto-close' do
      let(:category) { Fabricate(:category, auto_close_hours: nil) }

      it 'should not schedule the topic to auto-close' do
        expect(topic.public_topic_timer).to eq(nil)
        expect(job_klass.jobs).to eq([])
      end
    end

    context 'jobs may be queued' do
      before do
        freeze_time
      end

      context 'category has a default auto-close' do
        let(:category) { Fabricate(:category, auto_close_hours: 2.0) }

        it 'should schedule the topic to auto-close' do
          topic

          topic_status_update = TopicTimer.last

          expect(topic_status_update.topic).to eq(topic)
          expect(topic.public_topic_timer.execute_at).to be_within_one_second_of(2.hours.from_now)

          args = job_klass.jobs.last['args'].first

          expect(args["topic_timer_id"]).to eq(topic.public_topic_timer.id)
          expect(args["state"]).to eq(true)
        end

        context 'topic was created by staff user' do
          let(:admin) { Fabricate(:admin) }
          let(:staff_topic) { Fabricate(:topic, user: admin, category: category) }

          it 'should schedule the topic to auto-close' do
            staff_topic

            topic_status_update = TopicTimer.last

            expect(topic_status_update.topic).to eq(staff_topic)
            expect(topic_status_update.execute_at).to be_within_one_second_of(2.hours.from_now)
            expect(topic_status_update.user).to eq(admin)

            args = job_klass.jobs.last['args'].first

            expect(args["topic_timer_id"]).to eq(topic_status_update.id)
            expect(args["state"]).to eq(true)
          end

          context 'topic is closed manually' do
            it 'should remove the schedule to auto-close the topic' do
              freeze_time

              topic_timer_id = staff_topic.public_topic_timer.id

              staff_topic.update_status('closed', true, admin)

              expect(TopicTimer.with_deleted.find(topic_timer_id).deleted_at)
                .to be_within(1.second).of(Time.zone.now)
            end
          end
        end

        context 'topic was created by a non-staff user' do
          let(:regular_user) { Fabricate(:user) }
          let(:regular_user_topic) { Fabricate(:topic, user: regular_user, category: category) }

          it 'should schedule the topic to auto-close' do
            regular_user_topic

            topic_status_update = TopicTimer.last

            expect(topic_status_update.topic).to eq(regular_user_topic)
            expect(topic_status_update.execute_at).to be_within_one_second_of(2.hours.from_now)
            expect(topic_status_update.user).to eq(Discourse.system_user)

            args = job_klass.jobs.last['args'].first

            expect(args["topic_timer_id"]).to eq(topic_status_update.id)
            expect(args["state"]).to eq(true)
          end
        end
      end
    end
  end
end
