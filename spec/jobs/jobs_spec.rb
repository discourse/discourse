require 'rails_helper'
require_dependency 'jobs/base'

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

  describe 'cancel_scheduled_job' do
    it 'deletes the matching job' do
      job_to_delete = stub_everything(klass: 'Sidekiq::Extensions::DelayedClass', args: [YAML.dump(['Jobs::DrinkBeer', :delayed_perform, [{beer_id: 42}]])])
      job_to_delete.expects(:delete)
      job_to_keep1 = stub_everything(klass: 'Sidekiq::Extensions::DelayedClass', args: [YAML.dump(['Jobs::DrinkBeer', :delayed_perform, [{beer_id: 43}]])])
      job_to_keep1.expects(:delete).never
      job_to_keep2 = stub_everything(klass: 'Sidekiq::Extensions::DelayedClass', args: [YAML.dump(['Jobs::DrinkBeer', :delayed_perform, [{beer_id: 44}]])])
      job_to_keep2.expects(:delete).never
      Sidekiq::ScheduledSet.stubs(:new).returns( [job_to_keep1, job_to_delete, job_to_keep2] )
      expect(Jobs.cancel_scheduled_job(:drink_beer, {beer_id: 42})).to eq(true)
    end

    it 'returns false when no matching job is scheduled' do
      job_to_keep = stub_everything(klass: 'Sidekiq::Extensions::DelayedClass', args: [YAML.dump(['Jobs::DrinkBeer', :delayed_perform, [{beer_id: 43}]])])
      job_to_keep.expects(:delete).never
      Sidekiq::ScheduledSet.stubs(:new).returns( [job_to_keep] )
      expect(Jobs.cancel_scheduled_job(:drink_beer, {beer_id: 42})).to eq(false)
    end
  end

  describe 'enqueue_at' do
    it 'calls enqueue_in for you' do
      Timecop.freeze(Time.zone.now) do
        Jobs.expects(:enqueue_in).with(3 * 60 * 60, :eat_lunch, {}).returns(true)
        Jobs.enqueue_at(3.hours.from_now, :eat_lunch, {})
      end
    end

    it 'handles datetimes that are in the past' do
      Timecop.freeze(Time.zone.now) do
        Jobs.expects(:enqueue_in).with(0, :eat_lunch, {}).returns(true)
        Jobs.enqueue_at(3.hours.ago, :eat_lunch, {})
      end
    end
  end

end

