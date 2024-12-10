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

  class ConcurrentJob < ::Jobs::Base
    cluster_concurrency 1

    def self.stop!
      @stop = true
    end

    def self.stop
      @stop
    end

    def self.running?
      @running
    end

    def self.running=(val)
      @running = val
    end

    def execute(args)
      self.class.running = true
      sleep 0.0001 while !self.class.stop
    ensure
      self.class.running = false
    end
  end

  it "handles job concurrency" do
    ConcurrentJob.clear_cluster_concurrency_lock!

    expect(ConcurrentJob.get_cluster_concurrency).to eq(1)
    expect(BadJob.get_cluster_concurrency).to eq(nil)

    expect(Sidekiq::Queues["default"].size).to eq(0)

    thread = Thread.new { ConcurrentJob.new.perform({ "test" => 100 }) }

    wait_for { ConcurrentJob.running? }

    ConcurrentJob.new.perform({ "test" => 100 })

    expect(Sidekiq::Queues["default"].size).to eq(1)
    expect(Sidekiq::Queues["default"][0]["args"][0]).to eq("test" => 100)
  ensure
    ConcurrentJob.stop!
    thread.join
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

  context "when `Discourse.enable_sidekiq_logging?` is `true`" do
    let(:tmp_log_file) { Tempfile.new("sidekiq.log") }

    before do
      Discourse.enable_sidekiq_logging
      described_class::JobInstrumenter.set_log_path(tmp_log_file.path)
    end

    after do
      Discourse.disable_sidekiq_logging
      described_class::JobInstrumenter.reset_log_path
      tmp_log_file.close
    end

    it "should log the job in the sidekiq log file" do
      job = GoodJob.new
      job.perform({ some_param: "some_value" })

      parsed_logline = JSON.parse(File.read(tmp_log_file.path).split("\n").first)

      expect(parsed_logline["hostname"]).to be_present
      expect(parsed_logline["pid"]).to be_present
      expect(parsed_logline["database"]).to eq(RailsMultisite::ConnectionManagement.current_db)
      expect(parsed_logline["job_name"]).to eq("GoodJob")
      expect(parsed_logline["job_type"]).to eq("regular")
      expect(parsed_logline["status"]).to eq("success")
      expect(JSON.parse(parsed_logline["opts"])).to eq("some_param" => "some_value")
      expect(parsed_logline["duration"]).to be_present
      expect(parsed_logline["sql_duration"]).to eq(0)
      expect(parsed_logline["sql_calls"]).to eq(0)
      expect(parsed_logline["redis_duration"]).to eq(0)
      expect(parsed_logline["redis_calls"]).to eq(0)
      expect(parsed_logline["net_duration"]).to eq(0)
      expect(parsed_logline["net_calls"]).to eq(0)
      expect(parsed_logline["live_slots_finish"]).to be_present
      expect(parsed_logline["live_slots"]).to be_present
    end
  end
end
