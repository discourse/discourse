# frozen_string_literal: true

RSpec.describe Scheduler::Defer do
  let(:defer) { Class.new { include Scheduler::Deferrable }.new }

  before do
    Discourse.catch_job_exceptions!
    defer.async = true
  end

  after do
    defer.stop!
    Discourse.reset_catch_job_exceptions!
  end

  describe "#later" do
    it "starts a new worker after the previous worker stops" do
      completed = Queue.new
      defer.stop!

      defer.later { completed << :completed }

      expect(completed.pop(timeout: 5)).to eq(:completed)
    end

    let(:release) { Concurrent::IVar.new }
    let(:responses) { Thread::Queue.new }

    before do
      allow(RailsMultisite::ConnectionManagement).to receive(:with_connection) do |_db, &blk|
        blk.call
      end
    end

    def enqueue(db:, user_id:, request:)
      defer.later(nil, db, current_user: user_id) do
        release.value
        responses.push([db, user_id, request])
      end
    end

    it "runs jobs in a fair order" do
      enqueue(db: "site1", user_id: 1, request: 1)
      enqueue(db: "site1", user_id: 1, request: 2)
      enqueue(db: "site1", user_id: 2, request: 3)
      enqueue(db: "site2", user_id: 3, request: 4)
      enqueue(db: "site2", user_id: 4, request: 5)
      enqueue(db: "site2", user_id: 4, request: 6)

      release.set(nil)

      result = 6.times.map { responses.shift }

      expect(result).to eq(
        [
          ["site1", 1, 1],
          ["site2", 3, 4],
          ["site1", 2, 3],
          ["site2", 4, 5],
          ["site1", 1, 2],
          ["site2", 4, 6],
        ],
      )
    end
  end

  describe "#stop!" do
    it "finishes queued jobs before stopping" do
      completed = Queue.new
      defer.later { completed << :first }
      defer.later { completed << :second }

      defer.stop!(finish_work: true)

      expect(2.times.map { completed.pop(timeout: 5) }).to eq(%i[first second])
      expect(defer.stopped?).to eq(true)
    end
  end

  describe "#stats" do
    it "records completed jobs and errors by description" do
      defer.later("first") {}
      defer.later("first") {}
      defer.later("second") {}
      defer.later("bad") { raise "boom" }
      defer.stop!(finish_work: true)

      stats = defer.stats.to_h

      expect(stats["first"].slice(:queued, :finished, :errors)).to eq(
        queued: 2,
        finished: 2,
        errors: 0,
      )
      expect(stats["second"].slice(:queued, :finished, :errors)).to eq(
        queued: 1,
        finished: 1,
        errors: 0,
      )
      expect(stats["bad"].slice(:queued, :finished, :errors)).to eq(
        queued: 1,
        finished: 1,
        errors: 1,
      )
      expect(stats.values.map { |stat| stat[:duration] }).to all(be > 0)
    end
  end

  describe "#timeout=" do
    it "logs jobs that exceed the configured timeout" do
      defer.timeout = 0.05

      messages =
        track_log_messages do |logger|
          defer.later("slow job") { sleep }
          wait_for { logger.errors.length == 1 }
        end

      expect(messages.warnings).to eq([])
      expect(messages.fatals).to eq([])
      expect(messages.errors.length).to eq(1)
      expect(messages.errors.first).to match(/'slow job' is still running/)
    end
  end

  describe "#do_all_work" do
    it "runs queued jobs while the worker is paused" do
      completed = Queue.new
      defer.pause
      defer.later { completed << :completed }

      defer.do_all_work

      expect(completed.pop(timeout: 5)).to eq(:completed)
      expect(defer.length).to eq(0)
    end
  end

  describe "#pause" do
    it "finishes running and queued jobs before returning" do
      started = Queue.new
      release = Queue.new
      completed = Queue.new
      defer.later do
        started << true
        release.pop
        completed << :first
      end
      expect(started.pop(timeout: 5)).to eq(true)
      defer.later { completed << :second }

      pausing = Thread.new { defer.pause }
      expect(pausing.join(0.1)).to eq(nil)
      release << true

      expect(pausing.join(5)).to eq(pausing)
      expect(2.times.map { completed.pop(timeout: 5) }).to eq(%i[first second])
      expect(defer.stopped?).to eq(true)
    ensure
      release << true
      pausing&.join(5)
    end
  end

  describe "#resume" do
    it "keeps inherited jobs in the parent while running new child jobs" do
      reader, writer = IO.pipe
      defer.pause
      defer.later do
        writer.puts("parent")
        writer.flush
      end

      child =
        fork do
          reader.close
          defer.resume
          defer.later do
            writer.puts("child")
            writer.flush
          end
          defer.stop!(finish_work: true)
          exit!(0)
        end
      Process.waitpid(child)
      child = nil
      defer.resume
      defer.stop!(finish_work: true)
      writer.close

      expect(reader.read.lines.map(&:chomp)).to eq(%w[child parent])
    ensure
      if child
        begin
          Process.kill("KILL", child)
        rescue StandardError
          nil
        end
        begin
          Process.waitpid(child)
        rescue StandardError
          nil
        end
      end
      reader&.close unless reader&.closed?
      writer&.close unless writer&.closed?
    end

    it "runs jobs queued while paused" do
      completed = Queue.new
      defer.pause
      defer.later { completed << :completed }
      expect(completed.pop(timeout: 0.1)).to eq(nil)

      defer.resume

      expect(completed.pop(timeout: 5)).to eq(:completed)
    end
  end
end
