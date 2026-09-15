# frozen_string_literal: true

require "timeout"
require "tmpdir"
require_relative "../../../lib/turbo_tests/work_queue"

RSpec.describe TurboTests::WorkQueue do
  def run_workers(files:, arguments: [], worker_arguments: nil, environment: {}, worker_count: 2)
    fixture_root = Dir.mktmpdir("leased-examples-source-")
    Dir[File.expand_path("fixtures/leased_examples/*.rb.fixture", __dir__)].each do |template|
      FileUtils.cp(template, File.join(fixture_root, File.basename(template, ".fixture")))
    end
    selected_files = files.map { |file| File.join(fixture_root, "#{file}.rb") }
    events = Queue.new
    work_queue =
      described_class.new(
        files: selected_files,
        worker_count: worker_count,
        events: events,
        startup_timeout: 10,
      )
    children = {}
    work_queue.start
    Dir.mktmpdir("leased-examples-fixture-") do |directory|
      event_path = File.join(directory, "events.jsonl")
      statuses = {}
      worker_count.times do |index|
        worker = index + 1
        env =
          environment.merge(
            "DISCOURSE_TURBO_RSPEC_WORK_QUEUE" => work_queue.path,
            "TEST_ENV_NUMBER" => worker.to_s,
            "SCHEDULER_FIXTURE_EVENTS" => event_path,
            "SPEC_OPTS" => nil,
          )
        command = [
          "bundle",
          "exec",
          "rspec",
          "--options",
          "/dev/null",
          "--require",
          File.expand_path("../../../lib/turbo_tests/leased_examples", __dir__),
          "--require",
          File.join(fixture_root, "helper.rb"),
          "--format",
          "progress",
          "--seed",
          "1234",
          *arguments,
          *(
            if worker_arguments
              worker_arguments.fetch(index).map { |file| File.join(fixture_root, file) }
            else
              selected_files
            end
          ),
        ]
        log_path = File.join(directory, "worker-#{worker}.log")
        File.open(log_path, "w", 0o600) do |output|
          pid = Process.spawn(env, *command, out: output, err: output, pgroup: true)
          children[pid] = worker
        end
      end
      Timeout.timeout(30) do
        until children.empty?
          children.keys.each do |pid|
            waited = Process.waitpid2(pid, Process::WNOHANG)
            next unless waited
            worker = children.delete(pid)
            status = waited.last
            statuses[worker] = status.exitstatus || 128 + status.termsig
            work_queue.worker_exited(worker: worker, status: statuses[worker])
          end
          sleep 0.01 unless children.empty?
        end
      end
      messages = []
      messages << events.pop until events.empty?
      rows =
        File.exist?(event_path) ? File.readlines(event_path).map { |line| JSON.parse(line) } : []
      sequence = File.readlines(work_queue.sequence_path).map { |line| JSON.parse(line) }
      logs = Dir[File.join(directory, "*.log")].map { |path| File.read(path) }.join("\n")
      yield work_queue, statuses, rows, sequence, messages, logs
    end
  ensure
    children&.each_key do |pid|
      Process.kill("KILL", -pid)
      Process.waitpid(pid)
    rescue Errno::ESRCH, Errno::ECHILD
    end
    work_queue&.close
    FileUtils.remove_entry(File.dirname(work_queue.path)) if work_queue&.path
    FileUtils.remove_entry(fixture_root) if fixture_root
  end

  describe "#complete?" do
    it "leases each file once while preserving suite and root context hooks" do
      run_workers(files: %w[first second]) do |queue, statuses, rows, sequence, messages, logs|
        expect(statuses.values).to eq([0, 0]), logs
        expect(queue.complete?).to eq(true), logs
        expect(messages.none? { |message| message[:type] == "dynamic_error" }).to eq(true)
        examples = rows.select { |row| row["event"] == "example" }
        expect(examples.map { |row| row["id"] }.uniq.length).to eq(5)
        expect(examples.length).to eq(5)
        expect(sequence.map { |row| File.basename(row["file"]) }).to contain_exactly(
          "first.rb",
          "second.rb",
        )
        expect(rows.count { |row| row["event"] == "before-suite" }).to eq(2)
        expect(rows.count { |row| row["event"] == "after-suite" }).to eq(2)
        %w[first other second].each do |root|
          expect(rows.count { |row| row["event"] == "before-#{root}" }).to eq(1)
          expect(rows.count { |row| row["event"] == "after-#{root}" }).to eq(1)
        end
        first_workers =
          examples.select { |row| row["id"].include?("/first.rb[") }.map { |row| row["worker"] }
        expect(first_workers.uniq.length).to eq(1)
      end
    end

    it "preserves filters and attributes shared examples to the including file" do
      run_workers(
        files: %w[first second],
        arguments: %w[--tag selected],
      ) do |queue, statuses, rows, _sequence, _messages, logs|
        expect(statuses.values).to eq([0, 0]), logs
        expect(queue.complete?).to eq(true), logs
        examples = rows.select { |row| row["event"] == "example" }
        expect(examples.length).to eq(4)
        expect(examples.map { |row| row["id"] }.uniq.length).to eq(4)
        expect(examples.any? { |row| row["id"].match?(%r{/first\.rb\[1:\d+:\d+\]\z}) }).to eq(true)
      end
    end

    it "retains normal example failures while completing the selected corpus" do
      run_workers(
        files: %w[first second],
        environment: {
          "SCHEDULER_FIXTURE_EXAMPLE_FAILURE" => "1",
        },
      ) do |queue, statuses, rows, _sequence, messages, logs|
        expect(statuses.values.sort).to eq([0, 1]), logs
        expect(queue.complete?).to eq(true), logs
        expect(messages.none? { |message| message[:type] == "dynamic_error" }).to eq(true)
        expect(rows.count { |row| row["event"] == "example" }).to eq(5)
      end
    end

    it "preserves example ID selection without running another root from the same file" do
      selection = ["first.rb[1:1]", "second.rb"]
      run_workers(
        files: %w[first second],
        worker_arguments: [selection, selection],
      ) do |queue, statuses, rows, _sequence, _messages, logs|
        expect(statuses.values).to eq([0, 0]), logs
        expect(queue.complete?).to eq(true), logs
        expect(rows.count { |row| row["event"] == "example" }).to eq(2)
        expect(rows.none? { |row| row["event"] == "before-other" }).to eq(true)
      end
    end

    it "runs suite teardown for workers whose filters select no examples" do
      run_workers(
        files: %w[first second],
        arguments: %w[--tag unselected],
      ) do |queue, statuses, rows, sequence, _messages, logs|
        expect(statuses.values).to eq([0, 0]), logs
        expect(queue.complete?).to eq(true), logs
        expect(sequence).to be_empty
        expect(rows.map { |row| row["event"] }).to contain_exactly(
          "before-suite",
          "after-suite",
          "before-suite",
          "after-suite",
        )
      end
    end

    it "stops issuing leases after fail-fast while running context and suite teardown" do
      run_workers(
        files: %w[first second crash],
        arguments: ["--fail-fast=1"],
        environment: {
          "SCHEDULER_FIXTURE_EXAMPLE_FAILURE" => "1",
        },
        worker_count: 1,
      ) do |queue, statuses, rows, sequence, _messages, logs|
        expect(statuses.values).to eq([1]), logs
        expect(queue.complete?).to eq(false)
        expect(sequence.map { |row| File.basename(row["file"]) }).to eq(%w[first.rb second.rb])
        expect(rows.count { |row| row["event"] == "after-second" }).to eq(1)
        expect(rows.count { |row| row["event"] == "after-suite" }).to eq(1)
      end
    end

    it "rejects disagreement before executing examples" do
      selections = [["first.rb"], ["second.rb"]]
      run_workers(
        files: %w[first second],
        worker_arguments: selections,
      ) do |queue, statuses, rows, sequence, messages, _logs|
        expect(queue.complete?).to eq(false)
        expect(statuses.values).to eq([1, 1])
        expect(rows.none? { |row| row["event"] == "example" }).to eq(true)
        expect(sequence).to be_empty
        expect(messages.any? { |message| message[:message] == "worker manifests disagree" }).to eq(
          true,
        )
      end
    end

    it "fails after a worker crash without leasing the interrupted file again" do
      run_workers(files: %w[first crash]) do |queue, statuses, _rows, sequence, messages, _logs|
        expect(queue.complete?).to eq(false)
        expect(statuses.values).to include(17)
        expect(sequence.count { |row| File.basename(row["file"]) == "crash.rb" }).to eq(1)
        expect(messages.any? { |message| message[:type] == "dynamic_error" }).to eq(true)
      end
    end

    it "does not hide failures in suite teardown" do
      run_workers(
        files: %w[first second],
        environment: {
          "SCHEDULER_FIXTURE_SUITE_FAILURE" => "1",
        },
      ) do |queue, statuses, _rows, _sequence, messages, _logs|
        expect(queue.complete?).to eq(false)
        expect(statuses.values).to eq([1, 1])
        expect(
          messages.any? do |message|
            message[:message] == "worker reported a failure outside examples"
          end,
        ).to eq(true)
      end
    end
  end
end
