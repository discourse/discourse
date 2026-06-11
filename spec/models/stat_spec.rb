# frozen_string_literal: true

RSpec.describe Stat do
  describe ".all_stats" do
    it "returns all the core and plugin stats registered" do
      expect(Stat.all_stats.keys).to include(:topics_30_days, :likes_30_days)
    end

    context "when display_eu_visitor_stats is enabled" do
      before { SiteSetting.display_eu_visitor_stats = true }

      it "returns the eu visitor stats" do
        expect(Stat.all_stats.keys).to include(:visitors_30_days, :eu_visitors_30_days)
      end
    end
  end

  describe "calculate" do
    it "returns the result of the stat block with the stat name as a prefix" do
      stat = Stat.new("test") { { "7_days" => 1, "30_days" => 10, "count" => 100 } }
      expect(stat.calculate).to eq({ test_7_days: 1, test_30_days: 10, test_count: 100 })
    end

    it "returns an empty hash if the stat block raises an error" do
      stat = Stat.new("test") { raise "Test error" }
      expect(stat.calculate).to eq({})
    end
  end

  context "when stat type is provided" do
    it "returns the stat type" do
      stat = Stat.new("test", stat_type: :test)
      expect(stat.stat_type).to eq(:test)
    end

    it "validates the stat type is a symbol and contains no weird chars" do
      expect { Stat.new("test", stat_type: :custom_stat_type) }.not_to raise_error
      expect { Stat.new("test", stat_type: "Test") }.to raise_error(ArgumentError)
      expect { Stat.new("test", stat_type: "Blah$&#*") }.to raise_error(ArgumentError)
      expect { Stat.new("test", stat_type: "Blah" * 21) }.to raise_error(ArgumentError)
    end

    it "returns the stat type as a wrapper key in the result" do
      stat =
        Stat.new("test", stat_type: :test) { { "7_days" => 1, "30_days" => 10, "count" => 100 } }
      expect(stat.calculate).to eq({ test: { test_7_days: 1, test_30_days: 10, test_count: 100 } })
    end

    it "merges multiple stats with the same stat type" do
      stats = [
        Stat.new("boards", stat_type: :kanban) { { count: 1 } },
        Stat.new("cards", stat_type: :kanban) { { count: 2 } },
      ]

      expect(Stat.send(:calculate, stats)).to eq({ kanban: { boards_count: 1, cards_count: 2 } })
    end
  end
end
