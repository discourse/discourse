# frozen_string_literal: true

require 'rails_helper'

describe Jobs do

  describe 'enqueue' do

    describe 'run_later!' do
      before do
        Jobs.run_later!
      end

      it 'enqueues a job in sidekiq' do
        Sidekiq::Testing.fake! do
          jobs = Jobs::ProcessPost.jobs

          jobs.clear
          Jobs.enqueue(:process_post, post_id: 1)
          expect(jobs.length).to eq(1)
          job = jobs.first

          expected = {
            "class" => "Jobs::ProcessPost",
            "args" => [{ "post_id" => 1, "current_site_id" => "default" }],
            "queue" => "default"
          }
          expect(job.slice("class", "args", "queue")).to eq(expected)
        end
      end

      it "enqueues the job after the current transaction has committed" do
        jobs = Jobs::ProcessPost.jobs
        expect(jobs.length).to eq(0)

        Jobs.enqueue(:process_post, post_id: 1)
        expect(jobs.length).to eq(1)

        ActiveRecord::Base.transaction do
          Jobs.enqueue(:process_post, post_id: 1)
          expect(jobs.length).to eq(1)
        end
        expect(jobs.length).to eq(2)

        # Failed transaction
        ActiveRecord::Base.transaction do
          Jobs.enqueue(:process_post, post_id: 1)
          raise ActiveRecord::Rollback
        end

        expect(jobs.length).to eq(2) # No change
      end

      it "does not pass current_site_id when 'all_sites' is present" do
        Sidekiq::Testing.fake! do
          jobs = Jobs::ProcessPost.jobs

          jobs.clear
          Jobs.enqueue(:process_post, post_id: 1, all_sites: true)

          expect(jobs.length).to eq(1)
          job = jobs.first

          expected = {
            "class" => "Jobs::ProcessPost",
            "args" => [{ "post_id" => 1 }],
            "queue" => "default"
          }
          expect(job.slice("class", "args", "queue")).to eq(expected)
        end
      end

      it "doesn't execute the job" do
        Sidekiq::Client.stubs(:enqueue)
        Jobs::ProcessPost.any_instance.expects(:perform).never
        Jobs.enqueue(:process_post, post_id: 1)
      end

      it "should enqueue with the correct database id when the current_site_id option is given" do

        Sidekiq::Testing.fake! do
          jobs = Jobs::ProcessPost.jobs

          jobs.clear
          Jobs.enqueue(:process_post, post_id: 1, current_site_id: 'test_db')

          expect(jobs.length).to eq(1)
          job = jobs.first

          expected = {
            "class" => "Jobs::ProcessPost",
            "args" => [{ "post_id" => 1, "current_site_id" => "test_db" }],
            "queue" => "default"
          }
          expect(job.slice("class", "args", "queue")).to eq(expected)
        end
      end
    end

    describe 'run_immediately!' do
      before do
        Jobs.run_immediately!
      end

      it "doesn't enqueue in sidekiq" do
        Sidekiq::Client.expects(:enqueue).with(Jobs::ProcessPost, {}).never
        Jobs.enqueue(:process_post, post_id: 1)
      end

      it "executes the job right away" do
        Jobs::ProcessPost.any_instance.expects(:perform).with("post_id" => 1, "sync_exec" => true, "current_site_id" => "default")
        Jobs.enqueue(:process_post, post_id: 1)
      end

      context 'and current_site_id option is given and does not match the current connection' do
        before do
          Sidekiq::Client.stubs(:enqueue)
          Jobs::ProcessPost.any_instance.stubs(:execute).returns(true)
        end

        it 'should raise an exception' do
          Jobs::ProcessPost.any_instance.expects(:execute).never
          RailsMultisite::ConnectionManagement.expects(:establish_connection).never

          expect {
            Jobs.enqueue(:process_post, post_id: 1, current_site_id: 'test_db')
          }.to raise_error(ArgumentError)
        end
      end
    end

  end

  describe 'cancel_scheduled_job' do
    let(:scheduled_jobs) { Sidekiq::ScheduledSet.new }

    after do
      scheduled_jobs.clear
    end

    it 'deletes the matching job' do
      Sidekiq::Testing.disable! do
        scheduled_jobs.clear
        expect(scheduled_jobs.size).to eq(0)

        Jobs.enqueue_in(1.year, :run_heartbeat, topic_id: 123)
        Jobs.enqueue_in(2.years, :run_heartbeat, topic_id: 456)
        Jobs.enqueue_in(3.years, :run_heartbeat, topic_id: 123, current_site_id: 'foo')
        Jobs.enqueue_in(4.years, :run_heartbeat, topic_id: 123, current_site_id: 'bar')

        expect(scheduled_jobs.size).to eq(4)

        Jobs.cancel_scheduled_job(:run_heartbeat, topic_id: 123)

        expect(scheduled_jobs.size).to eq(3)

        Jobs.cancel_scheduled_job(:run_heartbeat, topic_id: 123, all_sites: true)

        expect(scheduled_jobs.size).to eq(1)
      end
    end

  end

  describe 'enqueue_at' do
    it 'calls enqueue_in for you' do
      freeze_time

      expect_enqueued_with(job: :process_post, at: 3.hours.from_now) do
        Jobs.enqueue_at(3.hours.from_now, :process_post, {})
      end
    end

    it 'handles datetimes that are in the past' do
      freeze_time

      expect_enqueued_with(job: :process_post, at: Time.zone.now) do
        Jobs.enqueue_at(3.hours.ago, :process_post, {})
      end
    end
  end

end
