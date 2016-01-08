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


  before {
    SiteSetting.queue_jobs = true
    Jobs::CloseTopic.jobs.clear
  }

  context 'creating a topic without auto-close' do
    Given(:topic) { Fabricate(:topic, category: category) }

    context 'uncategorized' do
      Given(:category) { nil }
      Then { expect(topic.auto_close_at).to eq(nil) }
      And  { expect(scheduled_jobs_for(:close_topic)).to be_empty }
    end

    context 'category without default auto-close' do
      Given(:category) { Fabricate(:category, auto_close_hours: nil) }
      Then { expect(topic.auto_close_at).to eq(nil) }
      And  { expect(scheduled_jobs_for(:close_topic)).to be_empty }
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
        Given(:category) { Fabricate(:category, auto_close_hours: 2.0) }
        Then { expect(topic.auto_close_at).to be_within_one_second_of(2.hours.from_now) }
        And  { expect(topic.auto_close_started_at).to eq(Time.zone.now) }
        And  { expect(scheduled_jobs_for(:close_topic, {topic_id: topic.id}).size).to eq(1) }
        And  { expect(scheduled_jobs_for(:close_topic, {topic_id: category.topic.id})).to be_empty }

        context 'topic was created by staff user' do
          Given(:admin) { Fabricate(:admin) }
          Given(:staff_topic) { Fabricate(:topic, user: admin, category: category) }
          Then { expect(scheduled_jobs_for(:close_topic, {topic_id: staff_topic.id, user_id: admin.id}).size).to eq(1) }

          context 'topic is closed manually' do
            When { staff_topic.update_status('closed', true, admin) }
            Then { expect(staff_topic.reload.auto_close_at).to eq(nil) }
            And  { expect(staff_topic.auto_close_started_at).to eq(nil) }
          end
        end

        context 'topic was created by a non-staff user' do
          Given!(:system_user) { Discourse.system_user }
          Given { Discourse.stubs(:system_user).returns(system_user) }
          Given(:regular_user) { Fabricate(:user) }
          Given(:regular_user_topic) { Fabricate(:topic, user: regular_user, category: category) }
          Then { expect(scheduled_jobs_for(:close_topic, {topic_id: regular_user_topic.id, user_id: system_user.id}).size).to eq(1) }
        end

        context 'auto_close_hours of topic was set to 0' do
          Given(:dont_close_topic) { Fabricate(:topic, auto_close_hours: 0, category: category) }
          Then { expect(scheduled_jobs_for(:close_topic)).to be_empty }
        end

        context 'two topics in the category' do
          Given!(:other_topic) { Fabricate(:topic, category: category) }
          When { topic } # create the second topic
          Then { expect(scheduled_jobs_for(:close_topic).size).to eq(2) }
        end
      end

      context 'a topic that has been auto-closed' do
        Given(:admin)              { Fabricate(:admin) }
        Given!(:auto_closed_topic) { Fabricate(:topic, user: admin, closed: true, auto_close_at: 1.day.ago, auto_close_user_id: admin.id, auto_close_started_at: 6.days.ago) }
        When { auto_closed_topic.update_status('closed', false, admin) }
        Then { expect(auto_closed_topic.reload.auto_close_at).to eq(nil) }
        And  { expect(auto_closed_topic.auto_close_started_at).to eq(nil) }
      end
    end
  end
end
