# frozen_string_literal: true

RSpec.describe "tasks/db" do
  describe "db:seed" do
    around do |example|
      previous_raise_seed_errors = ENV.delete("RAISE_SEED_ERRORS")
      previous_enable_test_stdout = ENV.delete("RAILS_ENABLE_TEST_STDOUT")

      example.run
    ensure
      if previous_raise_seed_errors
        ENV["RAISE_SEED_ERRORS"] = previous_raise_seed_errors
      else
        ENV.delete("RAISE_SEED_ERRORS")
      end

      if previous_enable_test_stdout
        ENV["RAILS_ENABLE_TEST_STDOUT"] = previous_enable_test_stdout
      else
        ENV.delete("RAILS_ENABLE_TEST_STDOUT")
      end
    end

    it "prints the exception details and backtrace without raising" do
      error = ArgumentError.new("seed exploded")
      error.set_backtrace(["seed.rb:10:in 'run_seed'", "db.rake:20:in 'invoke_seed'"])
      SeedFu.stubs(:seed).raises(error)

      output = capture_stdout { invoke_rake_task("db:seed") }

      expect(output).to include("seed exploded")
      expect(output).to include("ArgumentError")
      expect(output).to include(*error.backtrace)
      expect(output.index(error.backtrace.first)).to be < output.index(error.backtrace.second)
    end

    it "reraises without printing when seed errors must raise" do
      ENV["RAISE_SEED_ERRORS"] = "1"
      error = ArgumentError.new("seed exploded")
      SeedFu.stubs(:seed).raises(error)
      raised_error = nil

      output =
        capture_stdout do
          invoke_rake_task("db:seed")
        rescue => caught_error
          raised_error = caught_error
        end

      expect(raised_error).to equal(error)
      expect(output).to be_empty
    end
  end
end
