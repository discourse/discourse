# encoding: UTF-8

require 'spec_helper'
require 'sidekiq/testing'

describe Topic do

  def scheduled_jobs_for(job_name, params={})
    Sidekiq::Extensions::DelayedClass.jobs.select do |job|
      job_args = YAML.load(job['args'][0])
      if job_args[0].to_s == "Jobs::#{job_name.to_s.camelcase}" and job_args[2] and job_args[2][0]
        matched = true
        params.each do |key, value|
          unless job_args[2][0][key] == value
            matched = false
            break
          end
        end
        matched
      end
    end
  end


  before { SiteSetting.stubs(:queue_jobs).returns(true) }

  context 'creating a topic without auto-close' do
    Given(:topic) { Fabricate(:topic, category: category) }

    context 'uncategorized' do
      Given(:category) { nil }
      Then { topic.auto_close_at.should be_nil }
      And  { scheduled_jobs_for(:close_topic).should be_empty }
    end

    context 'category without default auto-close' do
      Given(:category) { Fabricate(:category, auto_close_days: nil) }
      Then { topic.auto_close_at.should be_nil }
      And  { scheduled_jobs_for(:close_topic).should be_empty }
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
        Given(:category) { Fabricate(:category, auto_close_days: 2.0) }
        Then { topic.auto_close_at.should == 2.days.from_now }
        And  { topic.auto_close_started_at.should == Time.zone.now }
        And  { scheduled_jobs_for(:close_topic, {topic_id: topic.id}).should have(1).job }
        And  { scheduled_jobs_for(:close_topic, {topic_id: category.topic.id}).should be_empty }

        context 'topic was created by staff user' do
          Given(:admin) { Fabricate(:admin) }
          Given(:staff_topic) { Fabricate(:topic, user: admin, category: category) }
          Then { scheduled_jobs_for(:close_topic, {topic_id: staff_topic.id, user_id: admin.id}).should have(1).job }

          context 'topic is closed manually' do
            When { staff_topic.update_status('closed', true, admin) }
            Then { staff_topic.reload.auto_close_at.should be_nil }
            And  { staff_topic.auto_close_started_at.should be_nil }
          end
        end

        context 'topic was created by a non-staff user' do
          Given!(:system_user) { Discourse.system_user }
          Given { Discourse.stubs(:system_user).returns(system_user) }
          Given(:regular_user) { Fabricate(:user) }
          Given(:regular_user_topic) { Fabricate(:topic, user: regular_user, category: category) }
          Then { scheduled_jobs_for(:close_topic, {topic_id: regular_user_topic.id, user_id: system_user.id}).should have(1).job }
        end

        context 'auto_close_days of topic was set to 0' do
          Given(:dont_close_topic) { Fabricate(:topic, auto_close_days: 0, category: category) }
          Then { scheduled_jobs_for(:close_topic).should be_empty }
        end

        context 'two topics in the category' do
          Given!(:other_topic) { Fabricate(:topic, category: category) }
          When { topic } # create the second topic
          Then { scheduled_jobs_for(:close_topic).should have(2).jobs }
        end
      end
    end
  end
end
