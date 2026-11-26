# frozen_string_literal: true

require "open3"
require "tempfile"
require_relative "../helpers/ci_example_timeout"

RSpec.describe CiExampleTimeout do
  it "cancels the pending backtrace when an example returns or raises" do
    watchdog = described_class.new(1.5)
    expect do
      results = Array.new(100) { watchdog.run { :finished } }
      expect(results).to all(eq(:finished))
      sleep 0.6 # Let the last cancelled backtrace deadline pass while idle.
      expect { watchdog.run { raise "ordinary failure" } }.to raise_error("ordinary failure")
      sleep 0.6
    end.to output("").to_stdout
  ensure
    watchdog&.stop
  end

  it "dumps stacks, fails each stalled example and lets the next example run" do
    Tempfile.create(%w[ci_example_timeout .rb]) do |spec|
      spec.write(<<~RUBY)
        require #{File.expand_path("../helpers/ci_example_timeout", __dir__).inspect}
        RSpec.configure do |config|
          CiExampleTimeout.install(config, seconds: 1.25)
          logger = nil
          config.before(:suite) do
            logger = Thread.list.find { |thread| thread.name == "RSpec timeout backtraces" }
          end
          config.append_after(:suite) { puts "logger stopped" if logger && !logger.alive? }
        end

        RSpec.describe "timeout recovery", order: :defined do
          it("finishes immediately") { expect(true).to be(true) }
          it("stalls once") { sleep 10 }
          it("stalls again") { sleep 10 }
          it("runs after both timeouts") { expect(true).to be(true) }
        end
      RUBY
      spec.flush

      output, status =
        Open3.capture2e("bin/rspec", "-O", File::NULL, "--format", "documentation", spec.path)

      expect(status.exitstatus).to eq(1), output
      expect(output).to include(
        "4 examples, 2 failures",
        "runs after both timeouts",
        "logger stopped",
      )
      diagnostics = output.scan(/--- Potential timeout example ---\n([^\n]*)/).flatten
      expect(diagnostics).to match([include("stalls once"), include("stalls again")])
      expect(output.scan("Spec timed out after 1.25 seconds").size).to eq(2)
      dumps = output.scan(/Threads backtraces 1 second before timeout(.*?)::endgroup::/m).flatten
      expect(dumps.size).to eq(2)
      expect(dumps).to all(include(spec.path))
    end
  end
end
