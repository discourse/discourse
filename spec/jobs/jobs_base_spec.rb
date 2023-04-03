# frozen_string_literal: true

RSpec.describe ::Jobs::Base do
  class GoodJob < ::Jobs::Base
    attr_accessor :count
    def execute(args)
      self.count ||= 0
      self.count += 1
    end
  end

  class BadJob < ::Jobs::Base
    class BadJobError < StandardError
    end

    attr_accessor :fail_count

    def execute(args)
      @fail_count ||= 0
      @fail_count += 1
      raise BadJobError
    end
  end

  it "handles correct jobs" do
    job = GoodJob.new
    job.perform({})
    expect(job.count).to eq(1)
  end

  it "handles errors in multisite" do
    RailsMultisite::ConnectionManagement.expects(:all_dbs).returns(%w[default default default])
    # one exception per database
    Discourse.expects(:handle_job_exception).times(3)

    bad = BadJob.new
    expect { bad.perform({}) }.to raise_error(Jobs::HandledExceptionWrapper)
    expect(bad.fail_count).to eq(3)
  end

  describe "#perform" do
    context "when a job raises an error" do
      before { Discourse.reset_job_exception_stats! }

      after { Discourse.reset_job_exception_stats! }

      it "collects stats for failing jobs in Discourse.job_exception_stats" do
        bad = BadJob.new
        3.times do
          # During test env handle_job_exception errors out
          # in production this is suppressed
          expect { bad.perform({}) }.to raise_error(BadJob::BadJobError)
        end

        expect(Discourse.job_exception_stats).to eq({ BadJob => 3 })
      end
    end
  end

  it "delegates the process call to execute" do
    ::Jobs::Base.any_instance.expects(:execute).with({ "hello" => "world" })
    ::Jobs::Base.new.perform("hello" => "world")
  end

  it "converts to an indifferent access hash" do
    ::Jobs::Base.any_instance.expects(:execute).with(instance_of(HashWithIndifferentAccess))
    ::Jobs::Base.new.perform("hello" => "world")
  end

  context "with fake jobs" do
    let(:common_state) { [] }

    let(:test_job_1) do
      Class
        .new(Jobs::Base)
        .tap do |klass|
          state = common_state
          klass.define_method(:execute) { |args| state << "job_1_executed" }
        end
    end

    let(:test_job_2) do
      Class
        .new(Jobs::Base)
        .tap do |klass|
          state = common_state
          job_1 = test_job_1
          klass.define_method(:execute) do |args|
            state << "job_2_started"
            Jobs.enqueue(job_1)
            state << "job_2_finished"
          end
        end
    end

    it "runs jobs synchronously sequentially in tests" do
      Jobs.run_immediately!
      Jobs.enqueue(test_job_2)

      expect(common_state).to eq(%w[job_2_started job_2_finished job_1_executed])
    end
  end
end
