# frozen_string_literal: true

RSpec.describe Sidekiq::SuppressUserEmailErrors do
  let(:middleware) { described_class.new }
  let(:worker) { Jobs::UserEmail.new }
  let(:queue) { "default" }

  describe "#call" do
    context "with UserEmail jobs" do
      context "when retry_count is less than 3" do
        it "wraps the exception in HandledExceptionWrapper to suppress logging" do
          [0, 1, 2].each do |retry_count|
            job = { "class" => "Jobs::UserEmail", "retry_count" => retry_count }

            expect do
              middleware.call(worker, job, queue) { raise StandardError, "Email send failed" }
            end.to raise_error(Jobs::HandledExceptionWrapper) { |error|
              expect(error.cause).to be_a(StandardError)
              expect(error.cause.message).to eq("Email send failed")
            }
          end
        end
      end

      context "when retry_count is 3 or greater" do
        it "does not wrap the exception, allowing normal error logging" do
          [3, 4, 5].each do |retry_count|
            job = { "class" => "Jobs::UserEmail", "retry_count" => retry_count }

            expect do
              middleware.call(worker, job, queue) { raise StandardError, "Email send failed" }
            end.to raise_error(StandardError, "Email send failed")
          end
        end
      end
    end

    context "with non-UserEmail jobs" do
      let(:other_worker) { Jobs::ProcessPost.new }

      it "does not wrap exceptions from other job types" do
        job = { "class" => "Jobs::ProcessPost", "retry_count" => 0 }

        expect do
          middleware.call(other_worker, job, queue) { raise StandardError, "Other error" }
        end.to raise_error(StandardError, "Other error")
      end
    end

    context "when the job succeeds" do
      it "does not raise an error" do
        job = { "class" => "Jobs::UserEmail", "retry_count" => 0 }

        expect { middleware.call(worker, job, queue) { "success" } }.not_to raise_error
      end
    end
  end

  describe "integration with Sidekiq job processing" do
    fab!(:user) { Fabricate(:user, last_seen_at: 8.days.ago, last_emailed_at: 8.days.ago) }
    fab!(:popular_topic) { Fabricate(:topic, user: Fabricate(:admin), created_at: 1.hour.ago) }
    let(:sidekiq) { Sidekiq.default_configuration }

    around do |example|
      # Ensure our middleware is in the chain for these tests
      original_chain = sidekiq.server_middleware.entries.dup
      original_error_handlers = sidekiq.error_handlers.dup

      sidekiq.server_middleware.clear
      sidekiq.server_middleware.add Sidekiq::SuppressUserEmailErrors

      sidekiq.error_handlers.clear
      sidekiq.error_handlers << SidekiqLogsterReporter.new

      example.run
    ensure
      # Restore original middleware chain and error handlers
      sidekiq.server_middleware.clear
      original_chain.each { |entry| sidekiq.server_middleware.add entry.klass, *entry.args }

      sidekiq.error_handlers.clear
      original_error_handlers.each { |h| sidekiq.error_handlers << h }
    end

    before do
      allow_any_instance_of(Email::Sender).to receive(:send).and_raise(
        StandardError,
        "Email send failed",
      )
    end

    it "suppresses error logging for first 3 retries when processing through Sidekiq" do
      logger = instance_double(Logster::Logger)
      allow(Logster).to receive(:logger).and_return(logger)
      allow(logger).to receive(:add_with_opts)

      [0, 1, 2].each do |retry_count|
        # Simulate Sidekiq processing with retry_count in job payload
        job_args = { type: :digest, user_id: user.id }
        job_hash = {
          "class" => "Jobs::UserEmail",
          "args" => [job_args],
          "retry_count" => retry_count,
          "queue" => "default",
        }

        # Process through middleware stack and error handler
        error_raised = nil
        begin
          sidekiq.server_middleware.invoke(worker, job_hash, "default") { worker.execute(job_args) }
        rescue => e
          error_raised = e
          # Simulate what Sidekiq does - call error handlers
          sidekiq.error_handlers.each { |handler| handler.call(e, { job: job_hash }) }
        end

        # Verify error was raised (wrapped)
        expect(error_raised).to be_a(Jobs::HandledExceptionWrapper)

        # Verify no logging occurred (HandledExceptionWrapper skipped by reporter)
        expect(logger).not_to have_received(:add_with_opts)
      end
    end

    it "allows error logging after 3 retries when processing through Sidekiq" do
      # Track whether logging was attempted
      logging_occurred = false

      logger = instance_double(Logster::Logger)
      allow(Logster).to receive(:logger).and_return(logger)
      allow(logger).to receive(:add_with_opts) do
        logging_occurred = true
        true
      end
      allow(Discourse).to receive(:reset_active_record_cache_if_needed)

      # Simulate 4th attempt (retry_count = 3)
      job_args = { type: :digest, user_id: user.id }
      job_hash = {
        "class" => "Jobs::UserEmail",
        "args" => [job_args],
        "retry_count" => 3,
        "queue" => "default",
      }

      # Process through middleware stack and error handler
      error_raised = nil
      begin
        sidekiq.server_middleware.invoke(worker, job_hash, "default") { worker.execute(job_args) }
      rescue => e
        error_raised = e
        # Simulate what Sidekiq does - call error handlers with proper context
        sidekiq.error_handlers.each do |handler|
          handler.call(e, { context: "Job raised exception", job: job_hash })
        end
      end

      # Verify error was raised (unwrapped)
      expect(error_raised).to be_a(StandardError)
      expect(error_raised).not_to be_a(Jobs::HandledExceptionWrapper)

      # Verify logging occurred (normal error passes through to reporter)
      expect(logging_occurred).to be true
    end

    it "integrates correctly with SidekiqLogsterReporter" do
      # Test that HandledExceptionWrapper is skipped by the reporter
      reporter = SidekiqLogsterReporter.new
      wrapped_error = Jobs::HandledExceptionWrapper.new(StandardError.new("Test"))

      logger = instance_double(Logster::Logger)
      allow(Logster).to receive(:logger).and_return(logger)
      allow(logger).to receive(:add_with_opts)

      # Call reporter with wrapped error
      reporter.call(wrapped_error, { job: "Jobs::UserEmail" })

      # Verify no logging occurred (reporter returns early for HandledExceptionWrapper)
      expect(logger).not_to have_received(:add_with_opts)
    end
  end
end
