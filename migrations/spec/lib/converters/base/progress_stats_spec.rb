# frozen_string_literal: true

RSpec.describe ::Migrations::Converters::Base::ProgressStats do
  subject(:stats) { described_class.new }

  describe "#initialize" do
    it "starts at the correct values" do
      expect(stats.progress).to eq(1)
      expect(stats.warning_count).to eq(0)
      expect(stats.error_count).to eq(0)
    end
  end

  describe "attribute accessors" do
    it "allows reading and writing for :progress" do
      stats.progress = 10
      expect(stats.progress).to eq(10)
    end

    it "allows reading and writing for :warning_count" do
      stats.warning_count = 5
      expect(stats.warning_count).to eq(5)
    end

    it "allows reading and writing for :error_count" do
      stats.error_count = 3
      expect(stats.error_count).to eq(3)
    end
  end

  describe "#reset!" do
    before do
      stats.progress = 5
      stats.warning_count = 2
      stats.error_count = 3
      stats.reset!
    end

    it "resets progress to 1" do
      expect(stats.progress).to eq(1)
    end

    it "resets warning_count to 0" do
      expect(stats.warning_count).to eq(0)
    end

    it "resets error_count to 0" do
      expect(stats.error_count).to eq(0)
    end
  end

  describe "#log_info" do
    before { allow(::Migrations::Database::IntermediateDB::LogEntry).to receive(:create!) }

    it "logs an info message" do
      stats.log_info("Info message")

      expect(::Migrations::Database::IntermediateDB::LogEntry).to have_received(:create!).with(
        type: ::Migrations::Database::IntermediateDB::LogEntry::INFO,
        message: "Info message",
        exception: nil,
        details: nil,
      )
    end

    it "logs an info message with details" do
      stats.log_info("Info message", details: { key: "value" })

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
    before { allow(::Migrations::Database::IntermediateDB::LogEntry).to receive(:create!) }

    it "logs a warning message and increments warning_count" do
      expect { stats.log_warning("Warning message") }.to change { stats.warning_count }.by(1)

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
        stats.log_warning("Warning message", exception: exception, details: { key: "value" })
      }.to change { stats.warning_count }.by(1)

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
    before { allow(::Migrations::Database::IntermediateDB::LogEntry).to receive(:create!) }

    it "logs an error message and increments error_count" do
      expect { stats.log_error("Error message") }.to change { stats.error_count }.by(1)

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
        stats.log_error("Error message", exception: exception, details: { key: "value" })
      }.to change { stats.error_count }.by(1)

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

  describe "#==" do
    let(:other_stats) { described_class.new }

    it "returns true for objects with the same values" do
      expect(stats).to eq(other_stats)
    end

    it "returns false for objects with different values" do
      other_stats.progress = 2
      expect(stats).not_to eq(other_stats)
    end
  end
end
