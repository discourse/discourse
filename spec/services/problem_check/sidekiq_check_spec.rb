# frozen_string_literal: true

RSpec.describe ProblemCheck::SidekiqCheck do
  subject(:check) { described_class.new }

  describe ".call" do
    context "when Sidekiq processed a job recently" do
      before do
        Jobs.stubs(:last_job_performed_at).returns(1.minute.ago)
        Jobs.stubs(:queued).returns(1)
      end

      it { expect(check).to be_chill_about_it }
    end

    context "when last job processed was a long time ago, but no jobs are queued" do
      before do
        Jobs.stubs(:last_job_performed_at).returns(7.days.ago)
        Jobs.stubs(:queued).returns(0)
      end

      it { expect(check).to be_chill_about_it }
    end

    context "when no jobs have ever been processed, but no jobs are queued" do
      before do
        Jobs.stubs(:last_job_performed_at).returns(nil)
        Jobs.stubs(:queued).returns(0)
      end

      it { expect(check).to be_chill_about_it }
    end

    context "when no jobs were processed recently and some jobs are queued" do
      before do
        Jobs.stubs(:last_job_performed_at).returns(20.minutes.ago)
        Jobs.stubs(:queued).returns(1)
      end

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          'Sidekiq is not running. Many tasks, like sending emails, are executed asynchronously by Sidekiq. Please ensure at least one Sidekiq process is running. <a href="https://github.com/mperham/sidekiq" target="_blank">Learn about Sidekiq here</a>.',
        )
      end
    end

    context "when no jobs have ever been processed, and some jobs are queued" do
      before do
        Jobs.stubs(:last_job_performed_at).returns(nil)
        Jobs.stubs(:queued).returns(1)
      end

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          'Sidekiq is not running. Many tasks, like sending emails, are executed asynchronously by Sidekiq. Please ensure at least one Sidekiq process is running. <a href="https://github.com/mperham/sidekiq" target="_blank">Learn about Sidekiq here</a>.',
        )
      end
    end

    context "when there's a massive pile-up in the queue" do
      before do
        Jobs.stubs(:last_job_performed_at).returns(1.second.ago)
        Jobs.stubs(:queued).returns(100_000)
      end

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          "The number of queued jobs is 100000, which is high. This could indicate a problem with the Sidekiq process(es), or you may need to add more Sidekiq workers.",
        )
      end
    end
  end
end
