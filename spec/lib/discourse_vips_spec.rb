# frozen_string_literal: true

fork_test_skip = "requires Linux fork isolation" if RUBY_PLATFORM.match?(/darwin/)

RSpec.describe DiscourseVips do
  TEST_WORKER_PATH = Rails.root.join("spec/fixtures/discourse_vips/test_worker.rb").to_s

  after { described_class.before_fork }

  def use_test_worker
    described_class.before_fork
    command = described_class.send(:worker_command).dup
    command[-3] = TEST_WORKER_PATH
    described_class.stubs(:worker_command).returns(command)
  end

  def runtime_state
    JSON.parse(described_class.vips("test-runtime", operation: :test))
  end

  def wait_until(timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until yield
      raise "condition was not met" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.01
    end
  end

  def process_alive?(pid)
    Process.kill(0, pid)
    !File.read("/proc/#{pid}/stat").split.fetch(2).eql?("Z")
  rescue Errno::ESRCH
    false
  rescue Errno::ENOENT
    true
  end

  def blocked_request(directory, name, timeout: 5)
    marker_path = File.join(directory, "#{name}.started")
    release_path = File.join(directory, "#{name}.release")
    thread =
      Thread.new do
        described_class.vips(
          "test-block",
          marker_path,
          release_path,
          name,
          operation: :test,
          read: [directory],
          write: [directory],
          timeout:,
        )
      end
    wait_until { File.exist?(marker_path) }
    [thread, marker_path, release_path]
  end

  def raw_worker_response(payload)
    request_reader, request_writer = IO.pipe
    response_reader, response_writer = IO.pipe
    pid =
      Process.spawn(
        described_class.send(:worker_environment),
        *described_class.send(:worker_command),
        3 => request_reader,
        4 => response_writer,
        :in => File::NULL,
        :out => File::NULL,
        :close_others => true,
        :pgroup => true,
        :unsetenv_others => true,
      )
    request_reader.close
    response_writer.close
    request_writer.write(payload)
    request_writer.close
    response = Timeout.timeout(5) { response_reader.read }
    Process.waitpid(pid)
    response
  ensure
    [request_reader, request_writer, response_reader, response_writer].each do |io|
      io&.close unless io&.closed?
    end
    if pid && process_alive?(pid)
      Process.kill("KILL", -pid)
      Process.waitpid(pid)
    end
  end

  it "starts a minimal worker lazily and records image-processing instrumentation",
     skip: fork_test_skip do
    use_test_worker
    SiteSetting.instrument_image_processing = true

    events =
      DiscourseEvent.track_events(:image_processing_finished) do
        state = runtime_state
        expect(state.slice("rails", "bundler", "rubygems").values).to all(eq(false))
        expect(state["landlock"]).to eq(true)
        expect(state["ruby_threads"]).to eq(1)
        expect(state["native_tasks_after"]).to eq(state["native_tasks_before"])
        expect(state["operation_pid"]).not_to eq(state["worker_pid"])
      end

    expect(events.first[:params].first.except(:duration_seconds)).to eq(
      operation: "test",
      success: true,
    )
  end

  it "routes concurrent responses to the right callers without head-of-line blocking",
     skip: fork_test_skip do
    use_test_worker

    Dir.mktmpdir("discourse-vips-spec") do |directory|
      completions = Queue.new
      blocked, _, release_path = blocked_request(directory, "blocked")
      blocked.report_on_exception = false

      fast_threads =
        4.times.map do |index|
          Thread.new do
            5.times do |iteration|
              expected = "#{index}-#{iteration}"
              value = described_class.vips("test-return", expected, operation: :test)
              completions << [:fast, expected, value]
            end
          end
        end

      fast_results = 20.times.map { completions.pop(timeout: 5) }
      expect(fast_results).to all(
        satisfy { |result| result[0] == :fast && result[1].to_s == result[2] },
      )
      expect(blocked).to be_alive

      FileUtils.touch(release_path)
      expect(blocked.value).to eq("blocked")
      fast_threads.each(&:join)
    end
  end

  it "isolates operation errors, crashes, and timeouts", skip: fork_test_skip do
    use_test_worker
    worker_pid = runtime_state.fetch("worker_pid")

    SiteSetting.instrument_image_processing = true
    events =
      DiscourseEvent.track_events(:image_processing_finished) do
        expect { described_class.vips("unsupported", operation: :test) }.to raise_error(
          DiscourseVips::Error,
          "unsupported libvips operation",
        )
      end
    expect(events.first[:params].first.except(:duration_seconds)).to eq(
      operation: "test",
      success: false,
    )
    expect { described_class.vips("test-crash", operation: :test) }.to raise_error(
      DiscourseVips::Error,
      "libvips operation failed",
    )
    expect {
      described_class.vips("test-read", Rails.root.join("Gemfile"), operation: :test)
    }.to raise_error(DiscourseVips::Error, /Permission denied/)
    expect { described_class.vips("test-network", operation: :test) }.to raise_error(
      DiscourseVips::Error,
      /Operation not permitted/,
    )

    Dir.mktmpdir("discourse-vips-spec") do |directory|
      request, = blocked_request(directory, "timeout", timeout: 0.05)
      request.report_on_exception = false
      expect { request.value }.to raise_error(DiscourseVips::Error, "libvips operation timed out")
    end

    expect(runtime_state.fetch("worker_pid")).to eq(worker_pid)
  end

  it "fails pending requests, removes children, and restarts lazily after the worker crashes",
     skip: fork_test_skip do
    use_test_worker
    worker_pid = runtime_state.fetch("worker_pid")

    Dir.mktmpdir("discourse-vips-spec") do |directory|
      requests =
        2.times.map do |index|
          thread, marker_path, = blocked_request(directory, "crash-#{index}")
          thread.report_on_exception = false
          [thread, Integer(File.read(marker_path))]
        end

      Process.kill("KILL", worker_pid)
      requests.each { |thread, _| expect { thread.value }.to raise_error(DiscourseVips::Error) }
      requests.each { |_, child_pid| wait_until { !process_alive?(child_pid) } }

      expect(runtime_state.fetch("worker_pid")).not_to eq(worker_pid)
    end
  end

  it "owns a separate worker after a fork and cleans it up when that process exits",
     skip: fork_test_skip do
    use_test_worker
    parent_worker_pid = runtime_state.fetch("worker_pid")

    Dir.mktmpdir("discourse-vips-spec") do |directory|
      reader, writer = IO.pipe
      application_pid =
        fork do
          reader.close
          _, marker_path, = blocked_request(directory, "application-exit")
          writer.write(
            JSON.generate(
              worker_pid: runtime_state.fetch("worker_pid"),
              operation_pid: Integer(File.read(marker_path)),
            ),
          )
          writer.close
          exit! 0
        end
      writer.close
      child_processes = JSON.parse(reader.read)
      Process.waitpid(application_pid)

      expect(child_processes.fetch("worker_pid")).not_to eq(parent_worker_pid)
      child_processes.each_value { |pid| wait_until { !process_alive?(pid) } }
      expect(runtime_state.fetch("worker_pid")).to eq(parent_worker_pid)
    ensure
      reader&.close
      writer&.close
    end
  end

  it "rejects malformed protocol frames" do
    request = {
      id: 1,
      command: ["version"],
      read: [],
      write: [Dir.tmpdir],
      scratch: Dir.tmpdir,
      timeout: 1,
      nice: 10,
    }
    payloads = [
      "{\n",
      JSON.generate(request.merge(id: 0)) << "\n",
      (JSON.generate(request) << "\n") * 2,
      ("x" * (65 * 1024)) << "\n",
      JSON.generate(request),
    ]

    payloads.each do |payload|
      responses = raw_worker_response(payload).lines.map { |line| JSON.parse(line) }
      expect(responses).to include(a_hash_including("status" => "error"))
    end
  end

  it "runs supported operations through the image worker" do
    input_path = file_from_fixtures("cropped.png").path

    expect(
      described_class.vips(
        "dominant-color",
        input_path,
        operation: :upload_dominant_color,
        read: [input_path],
      ),
    ).to eq("171613")
  end
end
