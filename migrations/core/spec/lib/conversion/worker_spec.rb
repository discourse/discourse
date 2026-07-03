# frozen_string_literal: true

RSpec.describe Migrations::Conversion::Worker do
  subject(:worker) { described_class.new(index, input_queue, output_queue, job) }

  let(:index) { 1 }
  let(:input_queue) { Queue.new }
  let(:output_queue) { Queue.new }
  let(:job) do
    instance_double(Migrations::Conversion::ParallelJob, setup: nil, run: "result", cleanup: nil)
  end

  after do
    input_queue.close if !input_queue.closed?
    output_queue.close if !output_queue.closed?
  end

  describe "#start" do
    it "works when `input_queue` is empty" do
      expect do
        worker.start
        input_queue.close
        worker.wait
        output_queue.close
      end.not_to raise_error
    end

    it "uses `ForkManager.fork`" do
      allow(Migrations::ForkManager).to receive(:fork).and_call_original

      worker.start
      input_queue.close
      worker.wait
      output_queue.close

      expect(Migrations::ForkManager).to have_received(:fork)
    end

    it "writes the output of `job.run` into `output_queue`" do
      allow(job).to receive(:run) { |data| "run: #{data[:text]}" }

      worker.start
      input_queue << { text: "Item 1" } << { text: "Item 2" } << { text: "Item 3" }
      input_queue.close
      worker.wait
      output_queue.close

      expect(output_queue).to have_queue_contents("run: Item 1", "run: Item 2", "run: Item 3")
    end

    def create_progress_stats(progress: 1, warning_count: 0, error_count: 0)
      Migrations::Conversion::StepStats.new(progress:, warning_count:, error_count:)
    end

    it "writes objects to the `output_queue`" do
      all_stats = [
        create_progress_stats,
        create_progress_stats(warning_count: 1),
        create_progress_stats(warning_count: 1, error_count: 1),
        create_progress_stats(warning_count: 2, error_count: 1),
      ]

      allow(job).to receive(:run) do |data|
        index = data[:index]
        [index, all_stats[index]]
      end

      worker.start
      input_queue << { index: 0 } << { index: 1 } << { index: 2 } << { index: 3 }
      input_queue.close
      worker.wait
      output_queue.close

      expect(output_queue).to have_queue_contents(
        [0, all_stats[0]],
        [1, all_stats[1]],
        [2, all_stats[2]],
        [3, all_stats[3]],
      )
    end

    # Characterization specs: they pin the wire contract of the IPC pipeline
    # (currently Oj in `:object` mode) with payload shapes that real steps
    # produce. Items are echoed back by the job, so each spec exercises both
    # pipe directions with the same payload.
    describe "wire format" do
      def round_trip(*items)
        allow(job).to receive(:run) { |data| data }

        worker.start
        items.each { |item| input_queue << item }
        input_queue.close
        worker.wait
        output_queue.close

        results = []
        results << output_queue.pop until output_queue.empty?
        results
      end

      it "round-trips a site-settings-shaped item with nested hashes and a Time value" do
        item = {
          name: "logo_url",
          value: "/uploads/default/original/1X/logo.png",
          data_type: 18,
          updated_at: Time.utc(2023, 5, 17, 12, 34, 56, 789_123),
          uploads: [
            { id: 1, url: "/uploads/default/original/1X/logo.png", filename: "logo.png" },
            { id: 2, url: "/uploads/default/original/1X/logo2.png", filename: "logo2.png" },
          ],
        }

        result = round_trip(item).first

        expect(result).to eq(item)
        expect(result.keys).to all(be_a(Symbol))
        expect(result[:uploads].flat_map(&:keys)).to all(be_a(Symbol))
        expect(result[:updated_at]).to be_a(Time)
        expect(result[:updated_at]).to eq(item[:updated_at])
      end

      it "round-trips a wide users-shaped item with full fidelity" do
        item = {
          id: 42,
          username: "alice",
          name: "Alice Άλφα 𝒜",
          active: true,
          admin: false,
          moderator: false,
          staged: false,
          approved: true,
          approved_at: Time.utc(2020, 1, 2, 3, 4, 5),
          approved_by_id: 1,
          created_at: Time.utc(2019, 12, 31, 23, 59, 59, 999_999),
          first_seen_at: Time.utc(2020, 1, 2, 3, 4, 6),
          last_seen_at: Time.utc(2024, 11, 5, 6, 7, 8),
          silenced_till: nil,
          suspended_at: nil,
          suspended_till: nil,
          date_of_birth: Date.new(1990, 4, 1),
          ip_address: IPAddr.new("192.168.0.1"),
          registration_ip_address: IPAddr.new("2001:db8::1"),
          locale: nil,
          title: nil,
          trust_level: 2,
          group_locked_trust_level: nil,
          manual_locked_trust_level: nil,
          primary_group_id: nil,
          flair_group_id: nil,
          uploaded_avatar_id: 99,
          views: 1234,
          avatar_url: "/uploads/default/original/1X/avatar.png",
          avatar_filename: "avatar.png",
          avatar_origin: nil,
          avatar_user_id: 42,
        }

        result = round_trip(item).first

        expect(result).to eq(item)
        expect(result[:created_at]).to be_a(Time)
        expect(result[:date_of_birth]).to be_a(Date)
        expect(result[:ip_address]).to be_a(IPAddr)
      end

      it "round-trips string edge cases" do
        item = {
          emoji: "héllo wörld 👋🏼 🇦🇹 文字",
          newlines: "line1\nline2\r\nline3",
          quotes_and_backslashes: %q(she said "hi\there" \\ and left),
          control_chars: "tab\there\u0000null",
          large: "Ω" * 1_000_000,
        }

        result = round_trip(item).first

        expect(result).to eq(item)
        expect(result[:large].bytesize).to be >= 1_000_000
      end

      it "round-trips a realistic statements batch with stats on the return path" do
        statements = [
          [
            "INSERT INTO users (original_id, username, created_at, active) VALUES (?, ?, ?, ?)",
            [42, "alice", "2019-12-31T23:59:59Z", 1],
          ],
          [
            "INSERT INTO user_emails (user_id, email, \"primary\", created_at) VALUES (?, ?, ?, ?)",
            [42, "alice@example.com", 1, "2019-12-31T23:59:59Z"],
          ],
          [
            "INSERT INTO user_options (user_id, timezone, dark_scheme_id) VALUES (?, ?, ?)",
            [42, nil, nil],
          ],
        ]
        stats = create_progress_stats(progress: 1, warning_count: 2, error_count: 3)

        allow(job).to receive(:run).and_return([statements, stats])

        worker.start
        input_queue << { id: 42 }
        input_queue.close
        worker.wait
        output_queue.close

        result_statements, result_stats = output_queue.pop
        expect(result_statements).to eq(statements)
        expect(result_stats).to eq(stats)
      end

      it "preserves FIFO ordering under volume" do
        item_count = 2000

        results = round_trip(*(0...item_count).map { |i| { index: i, payload: "item #{i}" } })

        expect(results.map { |item| item[:index] }).to eq((0...item_count).to_a)
      end
    end

    it "runs `job.setup` once in the worker process before processing items" do
      temp_file = Tempfile.new("setup_check")
      temp_file_path = temp_file.path
      parent_pid = Process.pid

      allow(job).to receive(:setup) do
        process = Process.pid == parent_pid ? "parent" : "worker"
        File.write(temp_file_path, "setup in #{process}\n", mode: "a+")
      end
      allow(job).to receive(:run) do |data|
        File.write(temp_file_path, "run: #{data[:text]}\n", mode: "a+")
        data[:text]
      end

      worker.start
      input_queue << { text: "Item 1" } << { text: "Item 2" }
      input_queue.close
      worker.wait
      output_queue.close

      expect(File.read(temp_file_path)).to eq <<~LOG
        setup in worker
        run: Item 1
        run: Item 2
      LOG
    ensure
      temp_file.unlink
    end

    it "raises an error in the parent process when `job.setup` fails in the worker process" do
      allow(job).to receive(:setup) do
        $stderr.reopen(File::NULL) # silence the worker's backtrace in the test output
        raise Migrations::Conversion::SetupGuard::SetupError, "setup failed"
      end

      worker.start
      input_queue << { text: "Item 1" }
      input_queue.close

      expect { worker.wait }.to raise_error(
        described_class::CrashedError,
        /Worker process #{index} exited unexpectedly/,
      )
    end

    it "raises an error when the worker process dies even though no pipe write failed" do
      allow(job).to receive(:setup) { exit!(1) }

      worker.start
      input_queue.close

      expect { worker.wait }.to raise_error(described_class::CrashedError)
    end

    it "runs `job.cleanup` at the end" do
      temp_file = Tempfile.new("method_call_check")
      temp_file_path = temp_file.path

      allow(job).to receive(:run) do |data|
        File.write(temp_file_path, "run: #{data[:text]}\n", mode: "a+")
        data[:text]
      end
      allow(job).to receive(:cleanup) do
        File.write(temp_file_path, "cleanup\n", mode: "a+")
      end

      worker.start
      input_queue << { text: "Item 1" } << { text: "Item 2" } << { text: "Item 3" }
      input_queue.close
      worker.wait
      output_queue.close

      expect(File.read(temp_file_path)).to eq <<~LOG
        run: Item 1
        run: Item 2
        run: Item 3
        cleanup
      LOG
    ensure
      temp_file.unlink
    end
  end
end
