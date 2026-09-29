# frozen_string_literal: true

RSpec.describe ServiceKeeper do
  let(:tmpdir) { Dir.mktmpdir("service-keeper") }
  let(:socket_path) { File.join(tmpdir, "keeper.sock") }
  let(:ruby) { RbConfig.ruby }
  let!(:supervisor_pid) { Process.spawn("sleep", "600") }

  def sleeper_spec(seconds = "600")
    { "argv" => ["sleep", seconds] }
  end

  def wait_until(timeout: 10)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until yield
      raise "timed out" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.05
    end
  end

  def running?(pid)
    Demon::Base.running?(pid)
  end

  before do
    described_class.stubs(:socket_path).returns(socket_path)
    described_class.enable!(supervisor_pid:)
  end

  after do
    begin
      keeper_pid =
        described_class.send(:request, { "command" => "status" }, spawn_if_missing: false)["pid"]
      Process.kill("TERM", keeper_pid)
      wait_until { !running?(keeper_pid) }
    rescue ServiceKeeper::Error, Errno::ESRCH
    end

    begin
      Process.kill("KILL", supervisor_pid)
    rescue StandardError
      nil
    end
    begin
      Process.wait(supervisor_pid)
    rescue StandardError
      nil
    end
    described_class.disable!
    FileUtils.rm_rf(tmpdir)
  end

  it "starts a service once and keeps it running across identical requests" do
    pid = described_class.ensure_running("sleeper", sleeper_spec)

    expect(running?(pid)).to eq(true)
    expect(described_class.ensure_running("sleeper", sleeper_spec)).to eq(pid)
  end

  it "restarts a service whose spec changed" do
    old_pid = described_class.ensure_running("sleeper", sleeper_spec("600"))
    new_pid = described_class.ensure_running("sleeper", sleeper_spec("601"))

    expect(new_pid).not_to eq(old_pid)
    wait_until { !running?(old_pid) }
    expect(running?(new_pid)).to eq(true)
  end

  it "stops a service on request" do
    pid = described_class.ensure_running("sleeper", sleeper_spec)
    described_class.stop("sleeper")

    wait_until { !running?(pid) }
    expect(described_class.status["services"]).to eq({})
  end

  it "restarts a service that dies" do
    pid = described_class.ensure_running("sleeper", sleeper_spec)
    Process.kill("KILL", pid)

    wait_until { (new_pid = described_class.status.dig("services", "sleeper")) && new_pid != pid }
  end

  it "passes a listening socket and an owner pipe to the service" do
    listener_path = File.join(tmpdir, "service.sock")
    script = <<~RUBY
      server = UNIXServer.for_fd(Integer(ARGV[0]))
      owner = IO.for_fd(Integer(ARGV[1]))
      client = server.accept
      client.puts("hello")
      client.close
      owner.read
    RUBY

    pid =
      described_class.ensure_running(
        "echo",
        {
          "argv" => [ruby, "-rsocket", "-e", script, "%{listener_fd}", "%{owner_fd}"],
          "unix_listener" => listener_path,
          "owner_pipe" => true,
        },
      )

    expect(UNIXSocket.open(listener_path, &:gets)).to eq("hello\n")

    described_class.stop("echo")
    wait_until { !running?(pid) }
  end

  it "stops its services and exits when the supervisor is gone" do
    service_pid = described_class.ensure_running("sleeper", sleeper_spec)
    keeper_pid = described_class.status["pid"]

    Process.kill("KILL", supervisor_pid)
    Process.wait(supervisor_pid)

    wait_until { !running?(keeper_pid) && !running?(service_pid) }
  end
end
