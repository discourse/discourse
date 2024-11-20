# frozen_string_literal: true

RSpec.describe ::Migrations::Converters::Base::StepTracker do
  subject(:tracker) { described_class.new }

  before { allow(::Migrations::Database::IntermediateDB::LogEntry).to receive(:create!) }

  describe "#initialize" do
    it "starts at the correct values" do
      stats = tracker.stats
      expect(stats.progress).to eq(1)
      expect(stats.warning_count).to eq(0)
      expect(stats.error_count).to eq(0)
    end
  end

  describe "#progress=" do
    it "allows setting progress" do
      tracker.progress = 10
      expect(tracker.stats.progress).to eq(10)
    end
  end

  describe "#stats" do
    it "returns correct stats" do
      expect(tracker.stats).to eq(
        ::Migrations::Converters::Base::StepStats.new(
          progress: 1,
          warning_count: 0,
          error_count: 0,
        ),
      )

      tracker.progress = 5
      2.times { tracker.log_warning("Foo") }
      3.times { tracker.log_error("Foo") }

      expect(tracker.stats).to eq(
        ::Migrations::Converters::Base::StepStats.new(
          progress: 5,
          warning_count: 2,
          error_count: 3,
        ),
      )
    end
  end

  describe "#reset_stats!" do
    it "correctly resets stats" do
      tracker.progress = 5
      2.times { tracker.log_warning("Foo") }
      3.times { tracker.log_error("Foo") }

      expect(tracker.stats).to eq(
        ::Migrations::Converters::Base::StepStats.new(
          progress: 5,
          warning_count: 2,
          error_count: 3,
        ),
      )

      tracker.reset_stats!

      expect(tracker.stats).to eq(
        ::Migrations::Converters::Base::StepStats.new(
          progress: 1,
          warning_count: 0,
          error_count: 0,
        ),
      )
    end
  end

  describe "#log_info" do
    it "logs an info message" do
      tracker.log_info("Info message")

      expect(::Migrations::Database::IntermediateDB::LogEntry).to have_received(:create!).with(
        type: ::Migrations::Database::IntermediateDB::LogEntry::INFO,
        message: "Info message",
        exception: nil,
        details: nil,
      )
    end

    it "logs an info message with details" do
      tracker.log_info("Info message", details: { key: "value" })

      expect(::Migrations::Database::IntermediateDB::LogEntry).to have_received(:create!).with(
        type: ::Migrations::Database::IntermediateDB::LogEntry::INFO,
        message: "Info message",
        exception: nil,
        details: {
          key: "value",
        },
      )
    end
  end

  describe "#log_warning" do
    it "logs a warning message and increments warning_count" do
      expect { tracker.log_warning("Warning message") }.to change {
        tracker.stats.warning_count
      }.by(1)

      expect(::Migrations::Database::IntermediateDB::LogEntry).to have_received(:create!).with(
        type: ::Migrations::Database::IntermediateDB::LogEntry::WARNING,
        message: "Warning message",
        exception: nil,
        details: nil,
      )
    end

    it "logs a warning message with exception and details and increments warning_count" do
      exception = StandardError.new("Warning exception")

      expect {
        tracker.log_warning("Warning message", exception: exception, details: { key: "value" })
      }.to change { tracker.stats.warning_count }.by(1)

      expect(::Migrations::Database::IntermediateDB::LogEntry).to have_received(:create!).with(
        type: ::Migrations::Database::IntermediateDB::LogEntry::WARNING,
        message: "Warning message",
        exception: exception,
        details: {
          key: "value",
        },
      )
    end
  end

  describe "#log_error" do
    it "logs an error message and increments error_count" do
      expect { tracker.log_error("Error message") }.to change { tracker.stats.error_count }.by(1)

      expect(::Migrations::Database::IntermediateDB::LogEntry).to have_received(:create!).with(
        type: ::Migrations::Database::IntermediateDB::LogEntry::ERROR,
        message: "Error message",
        exception: nil,
        details: nil,
      )
    end

    it "logs an error message with exception and details and increments error_count" do
      exception = StandardError.new("Error exception")

      expect {
        tracker.log_error("Error message", exception: exception, details: { key: "value" })
      }.to change { tracker.stats.error_count }.by(1)

      expect(::Migrations::Database::IntermediateDB::LogEntry).to have_received(:create!).with(
        type: ::Migrations::Database::IntermediateDB::LogEntry::ERROR,
        message: "Error message",
        exception: exception,
        details: {
          key: "value",
        },
      )
    end
  end
end
