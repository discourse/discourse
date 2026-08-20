# frozen_string_literal: true

require "discourse/safe_exec"

RSpec.describe Discourse::SafeExec do
  describe ".capture" do
    it "delegates sandboxed execution to Landlock" do
      status = instance_double(Process::Status, exited?: true, exitstatus: 0)
      result =
        instance_double(
          Landlock::CaptureResult,
          stdout: "hello\n",
          stderr: "",
          status: status,
          output_truncated?: false,
        )

      allow(Landlock).to receive(:supported?).and_return(true)
      allow(Landlock).to receive(:capture).and_return(result)

      expect(
        described_class.capture(
          "echo",
          "hello",
          read: ["/tmp/input"],
          execute: described_class.default_execute_paths,
          timeout: 1,
          env: {
            "PATH" => ENV["PATH"].to_s,
          },
          unsetenv_others: true,
          rlimits: {
            cpu_seconds: 1,
          },
          seccomp_deny_network: true,
          max_output_bytes: 1024,
          truncate_output: true,
        ),
      ).to eq("hello\n")

      expect(Landlock).to have_received(:capture).with(
        %w[echo hello],
        read: ["/tmp/input"],
        write: [],
        execute: described_class.default_execute_paths,
        timeout: 1,
        failure_message: "",
        success_status_codes: [0],
        env: {
          "PATH" => ENV["PATH"].to_s,
        },
        unsetenv_others: true,
        chdir: nil,
        connect_tcp: [],
        bind_tcp: [],
        rlimits: {
          cpu_seconds: 1,
        },
        seccomp_deny_network: true,
        max_output_bytes: 1024,
        truncate_output: true,
      )
    end

    it "converts Landlock command failures to Discourse command errors" do
      status = instance_double(Process::Status, exited?: true, exitstatus: 1)
      result =
        instance_double(
          Landlock::CaptureResult,
          stdout: "",
          stderr: "nope",
          status: status,
          output_truncated?: false,
        )

      allow(Landlock).to receive(:supported?).and_return(true)
      allow(Landlock).to receive(:capture).and_return(result)

      expect { described_class.capture("false", failure_message: "failed") }.to raise_error(
        Discourse::Utils::CommandError,
        /failed\nnope/,
      )
    end

    it "yields a completed result once before returning" do
      status = instance_double(Process::Status, exited?: true, exitstatus: 0)
      result =
        instance_double(
          Landlock::CaptureResult,
          stdout: "hello\n",
          stderr: "",
          status: status,
          output_truncated?: false,
        )
      yielded_results = []

      allow(Landlock).to receive(:supported?).and_return(true)
      allow(Landlock).to receive(:capture).and_return(result)

      output =
        described_class.capture("echo", "hello") do |capture_result|
          yielded_results << capture_result
        end

      expect(output).to eq("hello\n")
      expect(yielded_results).to eq([result])
    end

    it "yields a completed result once before raising a command error" do
      status = instance_double(Process::Status, exited?: true, exitstatus: 1)
      result =
        instance_double(
          Landlock::CaptureResult,
          stdout: "",
          stderr: "nope",
          status: status,
          output_truncated?: false,
        )
      yielded_results = []

      allow(Landlock).to receive(:supported?).and_return(true)
      allow(Landlock).to receive(:capture).and_return(result)

      expect {
        described_class.capture("false") { |capture_result| yielded_results << capture_result }
      }.to raise_error(Discourse::Utils::CommandError)
      expect(yielded_results).to eq([result])
    end

    it "yields the result attached to a Landlock command error" do
      status = instance_double(Process::Status)
      result = instance_double(Landlock::CaptureResult)
      yielded_results = []

      allow(Landlock).to receive(:supported?).and_return(true)
      allow(Landlock).to receive(:capture).and_raise(
        Landlock::CommandError.new(
          "output limit",
          stdout: "out",
          stderr: "err",
          status: status,
          result:,
        ),
      )

      expect {
        described_class.capture("tool") { |capture_result| yielded_results << capture_result }
      }.to raise_error(Discourse::Utils::CommandError, /output limit/)
      expect(yielded_results).to eq([result])
    end

    it "converts Landlock::CommandError into a Discourse command error" do
      status = instance_double(Process::Status)
      yielded_results = []

      allow(Landlock).to receive(:supported?).and_return(true)
      allow(Landlock).to receive(:capture).and_raise(
        Landlock::CommandError.new("boom", stdout: "out", stderr: "err", status: status),
      )

      expect {
        described_class.capture("tool") { |result| yielded_results << result }
      }.to raise_error(Discourse::Utils::CommandError, /boom/)
      expect(yielded_results).to be_empty
    end

    it "returns truncated stdout without checking the terminated status" do
      status = instance_double(Process::Status, exited?: false, exitstatus: nil)
      result =
        instance_double(
          Landlock::CaptureResult,
          stdout: "x" * 1024,
          stderr: "",
          status: status,
          output_truncated?: true,
        )

      allow(Landlock).to receive(:supported?).and_return(true)
      allow(Landlock).to receive(:capture).and_return(result)

      expect(described_class.capture("tool", truncate_output: true)).to eq("x" * 1024)
    end

    it "runs unsandboxed when Landlock is unavailable on the system" do
      allow(Landlock).to receive(:supported?).and_return(false)
      allow(Discourse::Utils).to receive(:execute_command).and_return("hello\n")

      expect(described_class.capture("echo", "hello", chdir: "/tmp")).to eq("hello\n")

      expect(Discourse::Utils).to have_received(:execute_command).with(
        "echo",
        "hello",
        timeout: nil,
        failure_message: "",
        success_status_codes: [0],
        chdir: "/tmp",
        unsetenv_others: false,
      )
    end

    it "does not yield when Landlock is unavailable on the system" do
      allow(Landlock).to receive(:supported?).and_return(false)
      allow(Discourse::Utils).to receive(:execute_command).and_return("hello\n")
      yielded_results = []

      output = described_class.capture("echo", "hello") { |result| yielded_results << result }

      expect(output).to eq("hello\n")
      expect(yielded_results).to be_empty
    end

    it "still strips the child environment in the unsandboxed fallback" do
      allow(Landlock).to receive(:supported?).and_return(false)

      previous_secret = ENV["SAFE_EXEC_SECRET"]
      ENV["SAFE_EXEC_SECRET"] = "hidden"
      output =
        described_class.capture(
          "sh",
          "-c",
          "printf '%s' \"${SAFE_EXEC_SECRET-unset}\"",
          env: {
            "PATH" => ENV["PATH"].to_s,
          },
          unsetenv_others: true,
        )

      expect(output).to eq("unset")
    ensure
      if previous_secret.nil?
        ENV.delete("SAFE_EXEC_SECRET")
      else
        ENV["SAFE_EXEC_SECRET"] = previous_secret
      end
    end

    it "captures stdout from a landlocked subprocess" do
      skip "Landlock is not supported" if !described_class.landlock_supported?

      output =
        described_class.capture(
          "echo",
          "hello",
          read: described_class.default_read_paths,
          execute: described_class.default_execute_paths,
        )

      expect(output).to eq("hello\n")
    end

    it "denies access to paths outside of the Landlock policy" do
      skip "Landlock is not supported" if !described_class.landlock_supported?

      Tempfile.create("safe-exec") do |tempfile|
        tempfile.write("secret")
        tempfile.close

        expect {
          described_class.capture(
            "cat",
            tempfile.path,
            read: described_class.default_read_paths,
            execute: described_class.default_execute_paths,
          )
        }.to raise_error(Discourse::Utils::CommandError)
      end
    end

    it "can clear the child environment" do
      skip "Landlock is not supported" if !described_class.landlock_supported?

      previous_secret = ENV["SAFE_EXEC_SECRET"]
      ENV["SAFE_EXEC_SECRET"] = "hidden"
      output =
        described_class.capture(
          "sh",
          "-c",
          "printf '%s' \"${SAFE_EXEC_SECRET-unset}\"",
          read: described_class.default_read_paths,
          execute: described_class.default_execute_paths,
          env: {
            "PATH" => ENV["PATH"].to_s,
          },
          unsetenv_others: true,
        )

      expect(output).to eq("unset")
    ensure
      if previous_secret.nil?
        ENV.delete("SAFE_EXEC_SECRET")
      else
        ENV["SAFE_EXEC_SECRET"] = previous_secret
      end
    end

    it "denies network syscalls when requested" do
      skip "Landlock is not supported" if !described_class.landlock_supported?

      expect {
        described_class.capture(
          RbConfig.ruby,
          "-rsocket",
          "-e",
          "UDPSocket.new",
          read: described_class.default_read_paths,
          execute: described_class.default_execute_paths,
          env: {
            "PATH" => ENV["PATH"].to_s,
          },
          unsetenv_others: true,
          seccomp_deny_network: true,
        )
      }.to raise_error(Discourse::Utils::CommandError)
    end

    it "terminates commands that exceed the output limit" do
      skip "Landlock is not supported" if !described_class.landlock_supported?

      expect {
        described_class.capture(
          RbConfig.ruby,
          "-e",
          "STDOUT.write('x' * 2048)",
          read: described_class.default_read_paths,
          execute: described_class.default_execute_paths,
          env: {
            "PATH" => ENV["PATH"].to_s,
          },
          unsetenv_others: true,
          max_output_bytes: 1024,
        )
      }.to raise_error(Discourse::Utils::CommandError, /output exceeded 1024 bytes/)
    end

    it "truncates commands that exceed the output limit when requested" do
      skip "Landlock is not supported" if !described_class.landlock_supported?

      output =
        described_class.capture(
          RbConfig.ruby,
          "-e",
          "STDOUT.write('x' * 2048)",
          read: described_class.default_read_paths,
          execute: described_class.default_execute_paths,
          env: {
            "PATH" => ENV["PATH"].to_s,
          },
          unsetenv_others: true,
          max_output_bytes: 1024,
          truncate_output: true,
        )

      expect(output.bytesize).to eq(1024)
      expect(output).to eq("x" * 1024)
    end
  end
end
