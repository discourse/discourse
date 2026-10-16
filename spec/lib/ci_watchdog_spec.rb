# frozen_string_literal: true

require "open3"

RSpec.describe RSpec::Core::Configuration, "#around" do
  def run_ci_specs(examples)
    # Isolate the global around hook and shorten its timeout without changing this suite's watchdog.
    source = <<~RUBY
      require "rspec"
      require "timeout"
      Thread.new { sleep 20; Process.exit!(2) }
      load #{Rails.root.join("spec/support/ci.rb").to_s.inspect}

      include RSpec::Mocks::ExampleMethods
      RSpec::Mocks.with_temporary_scope do
        stub_const("PER_SPEC_TIMEOUT_SECONDS", 1.1)
        RSpec.describe "watchdog examples" do
          #{examples}
        end
        exit RSpec::Core::Runner.run(["--options", File::NULL, "--order", "defined"])
      end
    RUBY

    Open3.capture3(
      { "CI" => "1", "GITHUB_ACTIONS" => nil, "DISCOURSE_RSPEC_PROFILE_EACH_EXAMPLE" => nil },
      RbConfig.ruby,
      "-e",
      source,
      chdir: Dir.tmpdir,
    )
  end

  it "handles immediate examples and resumes after an exception without dumping backtraces" do
    output, errors, status = run_ci_specs(<<~RUBY)
      200.times { it("finishes immediately") {} }
      it("fails") { raise "example failure" }
      it("runs after failure") { expect(1 + 1).to eq(2) }
    RUBY

    expect(status.exitstatus).to eq(1), errors + output
    expect(output).to include("202 examples, 1 failure", "example failure")
    expect(output).not_to include("Threads backtraces", "Error in backtrace logger")
  end

  it "dumps backtraces once for a slow example and resets for the next example" do
    output, errors, status = run_ci_specs(<<~RUBY)
      it("runs slowly") { sleep 0.3 }
      it("runs next") { expect(1 + 1).to eq(2) }
    RUBY

    expect(status.exitstatus).to eq(0), errors + output
    expect(output).to include("2 examples, 0 failures")
    expect(output.scan("Threads backtraces").size).to eq(1)
    expect(output).not_to include("Error in backtrace logger")
  end

  it "times out an example and continues with the following example" do
    output, errors, status = run_ci_specs(<<~RUBY)
      it("times out") { sleep 5 }
      it("runs after timeout") { expect(1 + 1).to eq(2) }
    RUBY

    expect(status.exitstatus).to eq(1), errors + output
    expect(output).to include("2 examples, 1 failure", "SpecTimeoutError")
    expect(output.scan("Threads backtraces").size).to eq(1)
    expect(output).not_to include("Error in backtrace logger")
  end
end
