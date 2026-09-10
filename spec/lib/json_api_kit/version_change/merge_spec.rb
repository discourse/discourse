# frozen_string_literal: true

RSpec.describe JsonApiKit::VersionChange::Merge do
  subject(:merge) { described_class.new(from: [date_name, time_name], to: new_name, up:, down:) }

  let(:up) { ->(date, time) { "#{date} #{time}" } }
  let(:down) { ->(posted_at) { posted_at.to_s.split(" ") } }
  let(:date_name) { JsonApiKit::Name::Field.new(value: "posted_date", type: "topics") }
  let(:time_name) { JsonApiKit::Name::Field.new(value: "posted_time", type: "topics") }
  let(:new_name) { JsonApiKit::Name::Field.new(value: "posted_at", type: "topics") }

  describe "#current" do
    it "returns the new name" do
      expect(merge.current).to eq(new_name)
    end
  end

  describe "#current_pairs" do
    subject(:current_pairs) { merge.current_pairs(attributes) }

    let(:attributes) { { date_name => "2026-08-01", time_name => "00:00:00" } }

    it "returns one pair, the new name with the value the converter builds" do
      expect(current_pairs).to eq([[new_name, "2026-08-01 00:00:00"]])
    end

    context "when an old value is missing" do
      let(:attributes) { { date_name => "2026-08-01" } }

      it "gives the converter a null value in its place" do
        expect(current_pairs).to eq([[new_name, "2026-08-01 "]])
      end
    end
  end

  describe "#previous_names" do
    it "returns the old names in the order of the declaration" do
      expect(merge.previous_names).to eq([date_name, time_name])
    end
  end

  describe "#previous_pairs" do
    subject(:previous_pairs) { merge.previous_pairs("2026-08-01 00:00:00") }

    it "returns one pair per old name, in the order of the declaration" do
      expect(previous_pairs).to eq([[date_name, "2026-08-01"], [time_name, "00:00:00"]])
    end

    context "when the converter answers another count of values" do
      let(:down) { ->(posted_at) { [posted_at] } }

      it "raises with the two counts" do
        expect { previous_pairs }.to raise_error(ArgumentError, /1 value for 2 names/)
      end
    end

    context "when the converter answers one value and not an array" do
      let(:down) { ->(posted_at) { posted_at } }

      it "raises with the two counts" do
        expect { previous_pairs }.to raise_error(ArgumentError, /1 value for 2 names/)
      end
    end
  end
end
