# encoding: UTF-8

require 'rails_helper'
require 'sidekiq/testing'

describe Topic do

  def scheduled_jobs_for(job_name, params={})
    "Jobs::#{job_name.to_s.camelcase}".constantize.jobs.select do |job|
      job_args = job['args'][0]
      matched = true
      params.each do |key, value|
        unless job_args[key.to_s] == value
          matched = false
          break
        end
      end
      matched
    end
  end

  before do
    @original_value = SiteSetting.queue_jobs
    SiteSetting.queue_jobs = true
    Jobs::CloseTopic.jobs.clear
  end

  after do
    SiteSetting.queue_jobs = @original_value
  end

  context 'creating a topic without auto-close' do
    let(:topic) { Fabricate(:topic, category: category) }

    context 'uncategorized' do
      let(:category) { nil }

      it 'should not schedule the topic to auto-close' do
        expect(topic.auto_close_at).to eq(nil)
        expect(scheduled_jobs_for(:close_topic)).to be_empty
      end
    end

    context 'category without default auto-close' do
      let(:category) { Fabricate(:category, auto_close_hours: nil) }

      it 'should not schedule the topic to auto-close' do
        expect(topic.auto_close_at).to eq(nil)
        expect(scheduled_jobs_for(:close_topic)).to be_empty
      end
    end

    context 'jobs may be queued' do
      before do
        Timecop.freeze(Time.zone.now)
      end

      after do
        Timecop.return
        Sidekiq::Extensions::DelayedClass.jobs.clear
      end

      context 'category has a default auto-close' do
        let(:category) { Fabricate(:category, auto_close_hours: 2.0) }

        it 'should schedule the topic to auto-close' do
          expect(topic.auto_close_at).to be_within_one_second_of(2.hours.from_now)
          expect(topic.auto_close_started_at).to eq(Time.zone.now)
          expect(scheduled_jobs_for(:close_topic, {topic_id: topic.id}).size).to eq(1)
          expect(scheduled_jobs_for(:close_topic, {topic_id: category.topic.id})).to be_empty
        end

        context 'topic was created by staff user' do
          let(:admin) { Fabricate(:admin) }
          let(:staff_topic) { Fabricate(:topic, user: admin, category: category) }

          it 'should schedule the topic to auto-close' do
            expect(scheduled_jobs_for(:close_topic, {topic_id: staff_topic.id, user_id: admin.id}).size).to eq(1)
          end

          context 'topic is closed manually' do
            it 'should remove the schedule to auto-close the topic' do
              staff_topic.update_status('closed', true, admin)
              expect(staff_topic.reload.auto_close_at).to eq(nil)
              expect(staff_topic.auto_close_started_at).to eq(nil)
            end
          end
        end

        context 'topic was created by a non-staff user' do
          let(:regular_user) { Fabricate(:user) }
          let(:regular_user_topic) { Fabricate(:topic, user: regular_user, category: category) }

          it 'should schedule the topic to auto-close' do
            expect(scheduled_jobs_for(:close_topic, {topic_id: regular_user_topic.id, user_id: Discourse.system_user.id}).size).to eq(1)
          end
        end

        context 'auto_close_hours of topic was set to 0' do
          let(:dont_close_topic) { Fabricate(:topic, auto_close_hours: 0, category: category) }

          it 'should not schedule the topic to auto-close' do
            expect(scheduled_jobs_for(:close_topic)).to be_empty
          end
        end

        context 'two topics in the category' do
          let!(:other_topic) { Fabricate(:topic, category: category) }

          it 'should schedule the topic to auto-close' do
            topic

            expect(scheduled_jobs_for(:close_topic).size).to eq(2)
          end
        end
      end

      context 'a topic that has been auto-closed' do
        let(:admin)              { Fabricate(:admin) }
        let!(:auto_closed_topic) { Fabricate(:topic, user: admin, closed: true, auto_close_at: 1.day.ago, auto_close_user_id: admin.id, auto_close_started_at: 6.days.ago) }

        it 'should set the right attributes' do
          auto_closed_topic.update_status('closed', false, admin)
          expect(auto_closed_topic.reload.auto_close_at).to eq(nil)
          expect(auto_closed_topic.auto_close_started_at).to eq(nil)
        end
      end
    end
  end
end
