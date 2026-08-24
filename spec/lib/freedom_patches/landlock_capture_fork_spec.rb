# frozen_string_literal: true

RSpec.describe "Landlock.capture_fork" do
  it "captures output and returns a successful status" do
    result =
      Landlock.capture_fork(allow_unsupported: true, rlimits: { open_files: 64 }) do
        print "captured output"
        warn "captured error"
      end

    expect(result.stdout).to eq("captured output")
    expect(result.stderr).to eq("captured error\n")
    expect(result).to be_success
  end

  it "returns an unsuccessful status and the exception on stderr" do
    result =
      Landlock.capture_fork(allow_unsupported: true, rlimits: { open_files: 64 }) do
        raise "image operation failed"
      end

    expect(result.status.exitstatus).to eq(1)
    expect(result.stderr).to eq("RuntimeError: image operation failed\n")
    expect(result).not_to be_success
  end

  it "terminates a child that exceeds its deadline" do
    result =
      Landlock.capture_fork(allow_unsupported: true, timeout: 0.01, rlimits: { open_files: 64 }) do
        sleep 10
      end

    expect(result).to be_timed_out
    expect(result).not_to be_success
  end

  it "closes inherited IO objects" do
    reader, writer = IO.pipe

    result = Landlock.capture_fork(allow_unsupported: true) { print writer.closed? }

    expect(result.stdout).to eq("true")
  ensure
    reader&.close
    writer&.close
  end

  it "denies filesystem access outside the policy" do
    skip("Landlock unsupported on this host") unless Landlock.supported?

    Dir.mktmpdir do |directory|
      secret_path = File.join(directory, "secret")
      File.write(secret_path, "secret")

      result = Landlock.capture_fork(read: [], write: []) { File.read(secret_path) }

      expect(result.status.exitstatus).to eq(1)
      expect(result.stderr).to include("Errno::EACCES")
    end
  end
end
