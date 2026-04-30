# frozen_string_literal: true

require "discourse/safe_exec"

RSpec.describe Discourse::SafeExec do
  describe ".capture" do
    it "falls back to execute_command when Landlock is unavailable" do
      allow(described_class).to receive(:landlock_supported?).and_return(false)
      allow(Discourse::Utils).to receive(:execute_command).with(
        "echo",
        "hello",
        timeout: 1,
        failure_message: "failed",
        success_status_codes: [0],
        chdir: ".",
      ).and_return("hello\n")

      expect(described_class.capture("echo", "hello", timeout: 1, failure_message: "failed")).to eq(
        "hello\n",
      )
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

      output = nil
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
      if previous_secret.nil?
        ENV.delete("SAFE_EXEC_SECRET")
      else
        ENV["SAFE_EXEC_SECRET"] = previous_secret
      end

      expect(output).to eq("unset")
    end

    it "denies network syscalls when requested" do
      skip "seccomp is not supported" if !Discourse::Seccomp.supported?

      expect {
        described_class.capture(
          "ruby",
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
      allow(described_class).to receive(:landlock_supported?).and_return(false)

      expect {
        described_class.capture(
          RbConfig.ruby,
          "-e",
          "STDOUT.write('x' * 2048)",
          max_output_bytes: 1024,
        )
      }.to raise_error(Discourse::Utils::CommandError, /output exceeded 1024 bytes/)
    end

    it "truncates commands that exceed the output limit when requested" do
      allow(described_class).to receive(:landlock_supported?).and_return(false)

      output =
        described_class.capture(
          RbConfig.ruby,
          "-e",
          "STDOUT.write('x' * 2048)",
          max_output_bytes: 1024,
          truncate_output: true,
        )

      expect(output.bytesize).to eq(1024)
      expect(output).to eq("x" * 1024)
    end

    it "ignores unsupported rlimits" do
      allow(Process).to receive(:setrlimit).and_raise(NotImplementedError)

      expect { described_class.apply_rlimits(cpu_seconds: 1) }.not_to raise_error
    end
  end
end
