# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::StepLog do
  subject(:log) { described_class.new }

  describe "#info" do
    it "adds an info-level entry" do
      log.info("hello")
      expect(log.entries.size).to eq(1)
      entry = log.entries.first
      expect(entry["level"]).to eq("info")
      expect(entry["message"]).to eq("hello")
      expect(entry["at"]).to be_present
    end
  end

  describe "#warn" do
    it "adds a warn-level entry" do
      log.warn("careful")
      expect(log.entries.first["level"]).to eq("warn")
      expect(log.entries.first["message"]).to eq("careful")
    end
  end

  describe "#error" do
    it "adds an error-level entry" do
      log.error("broken")
      expect(log.entries.first["level"]).to eq("error")
      expect(log.entries.first["message"]).to eq("broken")
    end
  end

  describe "#kv" do
    it "adds a key/value entry at info level" do
      log.kv("user_id", "42")
      entry = log.entries.first
      expect(entry["level"]).to eq("info")
      expect(entry["key"]).to eq("user_id")
      expect(entry["value"]).to eq("42")
      expect(entry["at"]).to be_present
    end
  end

  describe "#errors?" do
    it "returns false when no errors" do
      log.info("fine")
      expect(log.errors?).to be(false)
    end

    it "returns true when error entries exist" do
      log.error("boom")
      expect(log.errors?).to be(true)
    end
  end

  describe "#empty?" do
    it "returns true when no entries" do
      expect(log).to be_empty
    end

    it "returns false when entries exist" do
      log.info("hi")
      expect(log).not_to be_empty
    end
  end

  describe "#merge" do
    it "copies entries from another StepLog" do
      other = described_class.new
      other.info("from other")
      other.error("other error")

      log.info("local")
      log.merge(other)

      expect(log.entries.size).to eq(3)
      expect(log.errors?).to be(true)
    end
  end

  describe "#as_json" do
    it "returns a serializable array" do
      log.info("hello")
      log.kv("key", "val")
      result = log.as_json
      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result.first).to include("level" => "info", "message" => "hello")
      expect(result.second).to include("level" => "info", "key" => "key", "value" => "val")
    end
  end

  describe "entry cap" do
    it "stops adding entries after MAX_ENTRIES and warns about truncation" do
      stub_const(DiscourseWorkflows::Executor::StepLog, :MAX_ENTRIES, 5) do
        7.times { |i| log.info("msg #{i}") }
        expect(log.entries.size).to eq(5)
        expect(log.entries.last).to include(
          "level" => "warn",
          "message" => "Log truncated at 5 entries",
        )
      end
    end
  end

  describe "#error_summary" do
    it "returns a summary of error entries" do
      log.error("first problem")
      log.error("second problem")
      expect(log.error_summary).to include("first problem")
    end
  end
end
