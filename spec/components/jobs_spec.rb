require 'spec_helper'
require 'jobs'

describe Jobs do

  describe 'enqueue' do

    describe 'when queue_jobs is true' do
      before do
        SiteSetting.expects(:queue_jobs?).at_least_once.returns(true)
      end

      it 'enqueues a job in sidekiq' do
        Sidekiq::Client.expects(:enqueue).with(Jobs::ProcessPost, post_id: 1, current_site_id: 'default')
        Jobs.enqueue(:process_post, post_id: 1)
      end

      it "does not pass current_site_id when 'all_sites' is present" do
        Sidekiq::Client.expects(:enqueue).with(Jobs::ProcessPost, post_id: 1)
        Jobs.enqueue(:process_post, post_id: 1, all_sites: true)
      end

      it "doesn't execute the job" do
        Sidekiq::Client.stubs(:enqueue)
        Jobs::ProcessPost.any_instance.expects(:perform).never
        Jobs.enqueue(:process_post, post_id: 1)
      end

      it "should enqueue with the correct database id when the current_site_id option is given" do
        Sidekiq::Client.expects(:enqueue).with do |arg1, arg2|
          arg2[:current_site_id] == 'test_db' && arg2[:sync_exec].nil?
        end
        Jobs.enqueue(:process_post, post_id: 1, current_site_id: 'test_db')
      end
    end

    describe 'when queue_jobs is false' do
      before do
        SiteSetting.expects(:queue_jobs?).at_least_once.returns(false)
      end

      it "doesn't enqueue in sidekiq" do
        Sidekiq::Client.expects(:enqueue).with(Jobs::ProcessPost, {}).never
        Jobs.enqueue(:process_post, post_id: 1)
      end

      it "executes the job right away" do
        Jobs::ProcessPost.any_instance.expects(:perform).with(post_id: 1, sync_exec: true, current_site_id: "default")
        Jobs.enqueue(:process_post, post_id: 1)
      end

      context 'and current_site_id option is given and does not match the current connection' do
        before do
          Sidekiq::Client.stubs(:enqueue)
          Jobs::ProcessPost.any_instance.stubs(:execute).returns(true)
        end

        it 'should not execute the job' do
          Jobs::ProcessPost.any_instance.expects(:execute).never
          Jobs.enqueue(:process_post, post_id: 1, current_site_id: 'test_db') rescue nil
        end

        it 'should raise an exception' do
          expect {
            Jobs.enqueue(:process_post, post_id: 1, current_site_id: 'test_db')
          }.to raise_error(ArgumentError)
        end

        it 'should not connect to the given database' do
          RailsMultisite::ConnectionManagement.expects(:establish_connection).never
          Jobs.enqueue(:process_post, post_id: 1, current_site_id: 'test_db') rescue nil
        end
      end
    end

  end

end

