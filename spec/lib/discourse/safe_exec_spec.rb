# frozen_string_literal: true

require "discourse/safe_exec"

RSpec.describe Discourse::SafeExec do
  describe ".capture" do
    it "delegates sandboxed execution to Landlock::SafeExec" do
      status = instance_double(Process::Status, exited?: true, exitstatus: 0)
      result =
        instance_double(
          Landlock::SafeExec::Result,
          stdout: "hello\n",
          stderr: "",
          status: status,
          output_truncated?: false,
        )

      allow(Landlock::SafeExec).to receive(:capture).and_return(result)

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

      expect(Landlock::SafeExec).to have_received(:capture).with(
        "echo",
        "hello",
        read: ["/tmp/input"],
        write: [],
        execute: described_class.default_execute_paths,
        timeout: 1,
        failure_message: "",
        success_status_codes: [0],
        env: {
          "PATH" => ENV["PATH"].to_s,
        },
        inherit_env: false,
        chdir: nil,
        connect_tcp: nil,
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
          Landlock::SafeExec::Result,
          stdout: "",
          stderr: "nope",
          status: status,
          output_truncated?: false,
        )

      allow(Landlock::SafeExec).to receive(:capture).and_return(result)

      expect { described_class.capture("false", failure_message: "failed") }.to raise_error(
        Discourse::Utils::CommandError,
        /failed\nnope/,
      )
    end

    it "returns truncated stdout without checking the terminated status" do
      status = instance_double(Process::Status, exited?: false, exitstatus: nil)
      result =
        instance_double(
          Landlock::SafeExec::Result,
          stdout: "x" * 1024,
          stderr: "",
          status: status,
          output_truncated?: true,
        )

      allow(Landlock::SafeExec).to receive(:capture).and_return(result)

      expect(described_class.capture("tool", truncate_output: true)).to eq("x" * 1024)
    end

    it "captures stdout from a landlocked subprocess" do
      skip "Landlock SafeExec is not supported" if !described_class.landlock_supported?

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
      skip "Landlock SafeExec is not supported" if !described_class.landlock_supported?

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
      skip "Landlock SafeExec is not supported" if !described_class.landlock_supported?

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
  end
end
